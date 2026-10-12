import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firebase_service.dart';
import '../services/mikrotik_service.dart';
import '../utils/app_strings.dart';

class BillDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic>? user;
  final List<dynamic> users;
  final VoidCallback onUpdate;
  final VoidCallback onUsersUpdate;
  final Function(Map<String, dynamic>) onCollectionAdd;
  const BillDetailScreen({super.key, required this.bill, this.user, required this.users, required this.onUpdate, required this.onUsersUpdate, required this.onCollectionAdd});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late Map<String, dynamic> bill;
  Map<String, dynamic>? user;
  TextEditingController partialCtrl = TextEditingController();
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    bill = Map<String, dynamic>.from(widget.bill);
    user = widget.user!= null? Map<String, dynamic>.from(widget.user!) : _findUser();
    int remaining = FirebaseService.parseAmount(bill['remainingDue']?? bill['totalAmount']?? bill['amount']);
    partialCtrl.text = remaining.toString();
  }

  Map<String, dynamic>? _findUser() {
    String cleanPhone = bill['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
    try {
      var found = widget.users.firstWhere((u) => u['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '') == cleanPhone);
      return Map<String, dynamic>.from(found);
    } catch (e) {
      return null;
    }
  }

  int get totalAmount => FirebaseService.parseAmount(bill['totalAmount']?? bill['amount']);
  int get remainingDue => FirebaseService.parseAmount(bill['remainingDue']?? totalAmount);
  int get paidAmount => FirebaseService.parseAmount(bill['paidAmount']?? 0);
  int get dueAmount => FirebaseService.parseAmount(bill['dueAmount']?? bill['pendingDue']?? 0);
  int get monthlyAmount => FirebaseService.parseAmount(bill['amount']);

  Future<void> _activateUserAndExtendExpiry() async {
    if (user == null) return;
    DateTime now = DateTime.now();
    DateTime currentExpiry;
    try {
      currentExpiry = user!['expiryDate']!= null? DateTime.fromMillisecondsSinceEpoch(user!['expiryDate']) : now;
    } catch (_) {
      currentExpiry = now;
    }
    DateTime newExpiry = currentExpiry.isAfter(now)? currentExpiry.add(Duration(days: 30)) : now.add(Duration(days: 30));

    String username = user!['username']?.toString()?? user!['pppoe_username']?.toString()?? '';
    String password = user!['password']?.toString()?? user!['pppoe_password']?.toString()?? '1234';
    String pkg = user!['package']?.toString()?? bill['package']?.toString()?? '10 Mbps';
    String profileForMT = pkg.replaceAll(" Mbps", "M").replaceAll(" ", "");
    String cleanPhone = user!['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');

    await FirebaseService.usersCol.doc(cleanPhone).update({
      'expiryDate': newExpiry.millisecondsSinceEpoch,
      'status': 'active',
      'lastActiveDate': now.millisecondsSinceEpoch,
    }).catchError((_) {});

    if (username.isNotEmpty) {
      try {
        try { await MikrotikService.createProfileIfNotExists(profileForMT); } catch (_) {}
        var result = await MikrotikService.createUser(username: username, password: password, profile: profileForMT).timeout(Duration(seconds: 10), onTimeout: () => {'ok': false});
        if (result['ok'] == false) {
          await MikrotikService.enableUser(username).timeout(Duration(seconds: 6), onTimeout: () => {'ok': false});
        } else {
          await MikrotikService.enableUser(username).timeout(Duration(seconds: 6), onTimeout: () => {'ok': false});
        }
      } catch (e) {
        debugPrint("Mikrotik active error: $e");
      }
    }

    if (mounted) {
      setState(() {
        user!['expiryDate'] = newExpiry.millisecondsSinceEpoch;
        user!['status'] = 'active';
      });
    }
    widget.onUsersUpdate();
  }

  Future<void> _fullPayActive() async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    try {
      int payNow = remainingDue;
      if (payNow <= 0) {
        await _activateUserAndExtendExpiry();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Already Paid - User Active kar diya"), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
        return;
      }
      String billId = bill['id'].toString();
      String cleanPhone = bill['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');

      await FirebaseService.billsCol.doc(billId).update({
        'isPaid': true,
        'isPartial': false,
        'paidAmount': totalAmount,
        'remainingDue': 0,
        'lastPaidAmount': payNow,
        'lastPaidDate': DateTime.now().toIso8601String(),
        'activeType': 'fullPay',
      });

      var colData = {
        'name': bill['name'],
        'phone': cleanPhone,
        'amount': payNow,
        'totalBillAmount': totalAmount,
        'remaining': 0,
        'package': bill['package'],
        'billMonth': bill['billMonth'],
        'billId': billId,
        'date': DateTime.now().toIso8601String(),
        'id': "${billId}_${DateTime.now().millisecondsSinceEpoch}",
        'type': 'bill_full',
      };
      await FirebaseService.collectionsCol.doc(colData['id']).set(colData);
      widget.onCollectionAdd(colData);

      if (user!= null) {
        await FirebaseService.updateUserDue(cleanPhone, 0);
        await FirebaseService.usersCol.doc(cleanPhone).update({'pendingDue': 0, 'lastPayment': payNow}).catchError((_) {});
      }

      await _activateUserAndExtendExpiry();

      setState(() {
        bill['isPaid'] = true;
        bill['isPartial'] = false;
        bill['paidAmount'] = totalAmount;
        bill['remainingDue'] = 0;
      });
      widget.onUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Full Pay Rs.$payNow - User Active + Expiry 30 din extend + Due clear"), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _partialPayActive() async {
    if (isProcessing) return;
    int entered = int.tryParse(partialCtrl.text)?? 0;
    if (entered <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Paise sahi likho"), backgroundColor: Colors.orange));
      return;
    }
    if (entered > remainingDue) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rs.$remainingDue se zyada nahi de sakte"), backgroundColor: Colors.red));
      return;
    }
    setState(() => isProcessing = true);
    try {
      String billId = bill['id'].toString();
      String cleanPhone = bill['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      int newPaidTotal = paidAmount + entered;
      int newRemaining = (totalAmount - newPaidTotal).clamp(0, totalAmount);
      bool isNowFullyPaid = newRemaining == 0;

      await FirebaseService.billsCol.doc(billId).update({
        'paidAmount': newPaidTotal,
        'remainingDue': newRemaining,
        'isPaid': isNowFullyPaid,
        'isPartial':!isNowFullyPaid && newPaidTotal > 0,
        'lastPaidAmount': entered,
        'lastPaidDate': DateTime.now().toIso8601String(),
        'activeType': isNowFullyPaid? 'fullPay' : 'partialPay',
      });

      var colData = {
        'name': bill['name'],
        'phone': cleanPhone,
        'amount': entered,
        'totalBillAmount': totalAmount,
        'remaining': newRemaining,
        'package': bill['package'],
        'billMonth': bill['billMonth'],
        'billId': billId,
        'date': DateTime.now().toIso8601String(),
        'id': "${billId}_${DateTime.now().millisecondsSinceEpoch}",
        'type': 'bill_partial',
      };
      await FirebaseService.collectionsCol.doc(colData['id']).set(colData);
      widget.onCollectionAdd(colData);

      if (user!= null) {
        await FirebaseService.updateUserDue(cleanPhone, newRemaining.toDouble());
        await FirebaseService.usersCol.doc(cleanPhone).update({'pendingDue': newRemaining, 'lastPayment': entered}).catchError((_) {});
      }

      await _activateUserAndExtendExpiry();

      setState(() {
        bill['paidAmount'] = newPaidTotal;
        bill['remainingDue'] = newRemaining;
        bill['isPaid'] = isNowFullyPaid;
        bill['isPartial'] =!isNowFullyPaid && newPaidTotal > 0;
      });
      widget.onUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Partial Rs.$entered liya - User Active, Baqaya Rs.$newRemaining Due me gaya + Expiry extend"), backgroundColor: Colors.orange, duration: Duration(seconds: 4)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _activeWithoutPay() async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    try {
      String billId = bill['id'].toString();
      await FirebaseService.billsCol.doc(billId).update({
        'isPaid': false,
        'isPartial': false,
        'activeWithoutPay': true,
        'lastActiveWithoutPayDate': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      await _activateUserAndExtendExpiry();
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Active Without Pay - User Active, Bill Pending me chala gaya, Due wese ka wesa"), backgroundColor: Colors.blue, duration: Duration(seconds: 4)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _showBillPdf() async {
    final pdf = pw.Document();
    String expiryStr = user!= null && user!['expiryDate']!= null
        ? () {
      try {
        DateTime d = DateTime.fromMillisecondsSinceEpoch(user!['expiryDate']);
        return "${d.day}/${d.month}/${d.year}";
      } catch (e) {
        return "-";
      }
    }()
        : "-";

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
              color: PdfColors.deepPurple,
              padding: pw.EdgeInsets.all(16),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(AppStrings.company, style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text("INTERNET BILL", style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold))
              ])),
          pw.SizedBox(height: 20),
          pw.Text("Customer Details", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Text("Name: ${bill['name']}"),
          pw.Text("Phone: ${bill['raw_phone']?? bill['phone']}"),
          pw.Text("Username: ${bill['username']?? user?['username']?? '-'}"),
          pw.Text("Package: ${bill['package']}"),
          pw.Text("Bill Month: ${bill['billMonth']}"),
          pw.Text("Expiry: $expiryStr"),
          pw.SizedBox(height: 10),
          pw.Text("Amount Details", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Text("Monthly Amount: Rs. $monthlyAmount"),
          pw.Text("Previous Due: Rs. $dueAmount"),
          pw.Text("Total Amount (Monthly + Due): Rs. $totalAmount"),
          pw.Text("Paid Amount: Rs. $paidAmount"),
          pw.Text("Remaining Due: Rs. $remainingDue"),
          pw.Text("Status: ${bill['isPaid'] == true? 'Paid' : bill['isPartial'] == true? 'Partial' : 'Pending'}"),
          pw.SizedBox(height: 20),
          pw.Text("Note: Agle month expire hone par ye baqaya Rs.$remainingDue agle bill me jama ho jayega", style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
          pw.SizedBox(height: 30),
          pw.Text("Thank you for using ${AppStrings.company}!", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text("Generated: ${DateTime.now().toString()}", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = bill['isPaid'] == true;
    bool isPartial = bill['isPartial'] == true;

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        title: Text("Bill Details", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf, color: Colors.white70), onPressed: _showBillPdf, tooltip: "PDF Share"),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Color(0xFF7C4DFF), radius: 28, child: Text(bill['name'].toString().isNotEmpty? bill['name'].toString()[0].toUpperCase() : "U", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bill['name']?? '-', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text("${bill['phone']} | ${bill['package']}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                            Text("Bill Month: ${bill['billMonth']}", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: isPaid? Colors.green.withOpacity(0.2) : isPartial? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(isPaid? "Paid" : isPartial? "Partial" : "Pending", style: GoogleFonts.poppins(color: isPaid? Colors.green : isPartial? Colors.orange : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(color: Colors.white12),
                  _rowDetail("Monthly Amount", "Rs. $monthlyAmount"),
                  _rowDetail("Previous Due", "Rs. $dueAmount"),
                  _rowDetail("Total Amount", "Rs. $totalAmount", isBold: true),
                  Divider(color: Colors.white12),
                  _rowDetail("Paid Amount", "Rs. $paidAmount", color: Colors.greenAccent),
                  _rowDetail("Remaining / Baqaya", "Rs. $remainingDue", color: Colors.redAccent, isBold: true),
                  if (user!= null)...[
                    Divider(color: Colors.white12),
                    _rowDetail("User Pending Due", "Rs. ${user!['pendingDue']?? 0}"),
                    _rowDetail("Expiry", user!['expiryDate']!= null? _formatExpiry(user!['expiryDate']) : '-', isRed: _isExpired()),
                    _rowDetail("Status", "${user!['status']?? 'disabled'}"),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20),
            Text("Payment Options", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Partial Amount (e.g. 300, 400, 600)", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  SizedBox(height: 8),
                  TextField(
                    controller: partialCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: "Rs. ",
                      prefixStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: "Kitne paise diye? e.g. 300",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Note: Jo baqaya bachega wo Due me chala jayega aur agle month ke bill me jama hoga", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.check_circle, color: Colors.white),
                label: Text("Full Pay Active - Rs.$remainingDue Pay + Active", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00C853), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isProcessing? null : _fullPayActive,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.payments, color: Colors.white),
                label: Text("Partial Pay Active - Jo diya Active + Baqaya Due", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isProcessing? null : _partialPayActive,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.wifi, color: Colors.white),
                label: Text("Active Without Pay - Bina paise Active, Bill Pending me", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isProcessing? null : _activeWithoutPay,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white70),
                label: Text("PDF - Bill Details Share", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white24), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _showBillPdf,
              ),
            ),
            if (isProcessing)...[
              SizedBox(height: 20),
              Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
            ],
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _rowDetail(String label, String value, {bool isBold = false, Color? color, bool isRed = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
          Text(value, style: GoogleFonts.poppins(color: color?? (isRed? Colors.redAccent : Colors.white), fontSize: isBold? 13 : 11, fontWeight: isBold? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatExpiry(dynamic ms) {
    try {
      DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
      return "${d.day}/${d.month}/${d.year}";
    } catch (e) {
      return ms.toString();
    }
  }

  bool _isExpired() {
    if (user == null || user!['expiryDate'] == null) return false;
    try {
      return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(user!['expiryDate']));
    } catch (_) {
      return false;
    }
  }
}