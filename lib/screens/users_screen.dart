import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:open_file/open_file.dart';

class UsersScreen extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> bills;
  final List<dynamic> collections;
  final VoidCallback onUsersUpdate;
  final VoidCallback onBillsUpdate;
  final VoidCallback onCollectionsUpdate;
  const UsersScreen({super.key, required this.users, required this.bills, required this.collections, required this.onUsersUpdate, required this.onBillsUpdate, required this.onCollectionsUpdate});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _firestore = FirebaseFirestore.instance;
  String search = "";
  bool isExcelLoading = false;
  bool isFabOpen = false; // POINT 9

  DateTime calculateExpiry(DateTime fromDate) {
    int year = fromDate.year; int month = fromDate.month + 1;
    if (month > 12) { month = 1; year++; }
    return DateTime(year, month, fromDate.day, 12, 0, 0);
  }
  String formatDate(int? millis) {
    if (millis == null) return "-";
    DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${d.day}/${d.month}/${d.year}";
  }
  String formatExpiryForExcel(int? millis) {
    if (millis == null) return "";
    DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
  }
  bool isExpired(Map<String, dynamic> user) {
    if (user['expiryDate'] == null) return false;
    try { return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(user['expiryDate'])); } catch (e) { return false; }
  }

  Future<void> collectDueAmount(Map<String, dynamic> user) async {
    int currentDue = (user['pendingDue']?? 0) is int? user['pendingDue'] : int.tryParse(user['pendingDue'].toString())?? 0;
    if (currentDue <= 0) return;
    final amountCtrl = TextEditingController(text: currentDue.toString());
    bool? ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("Collect Due - ${user['name']}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)), child: Row(children: [Icon(Icons.warning_amber, color: Colors.amber), SizedBox(width: 8), Text("Due: $currentDue Rs", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))])),
        SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Kitna Collect Karna Hai?", prefixIcon: Icon(Icons.payments, color: Colors.green), filled: true, fillColor: Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: () => Navigator.pop(ctx, true), child: Text("Collect"))],
    ));
    if (ok!= true) return;
    int collected = int.tryParse(amountCtrl.text)?? 0;
    if (collected <= 0) return;
    if (collected > currentDue) collected = currentDue;
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      String phoneKey = user['phone'].toString();
      int newDue = currentDue - collected;
      final now = DateTime.now();
      String docId = now.millisecondsSinceEpoch.toString();
      await _firestore.collection('isps').doc(uid).collection('my_users').doc(phoneKey).update({'pendingDue': newDue});
      await _firestore.collection('isps').doc(uid).collection('my_collections').doc(docId).set({
        'id': docId, 'phone': phoneKey, 'name': user['name'], 'amount': collected,
        'package': user['package']?? '10 Mbps', 'type': 'due_collection',
        'billMonth': "${now.year}-${now.month}", 'date': now.toIso8601String(),
      });
      widget.collections.add({
        'id': docId, 'phone': phoneKey, 'name': user['name'], 'amount': collected,
        'package': user['package']?? '10 Mbps', 'type': 'due_collection',
        'billMonth': "${now.year}-${now.month}", 'date': now.toIso8601String(),
      });
      setState(() {
        int idx = widget.users.indexWhere((u) => u['phone'].toString() == phoneKey);
        if (idx!= -1) widget.users[idx]['pendingDue'] = newDue;
      });
      widget.onUsersUpdate(); widget.onCollectionsUpdate();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$collected Rs Due Collected, Baki: $newDue Rs"), backgroundColor: Colors.green));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)); }
  }

  Future<void> exportToExcel() async {
    setState(() => isExcelLoading = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid?? "admin";
      var excel = ex.Excel.createExcel();
      ex.Sheet sheet = excel['Sheet1'];
      sheet.appendRow([ex.TextCellValue('username'), ex.TextCellValue('ct_password'), ex.TextCellValue('profile_name'), ex.TextCellValue('expiration'), ex.TextCellValue('parent_name'), ex.TextCellValue('app_username'), ex.TextCellValue('app_password')]);
      for (var u in widget.users) {
        sheet.appendRow([ex.TextCellValue((u['pppoe_username']?? u['phone']?? '').toString()), ex.TextCellValue((u['pppoe_password']?? '').toString()), ex.TextCellValue((u['package']?? '').toString()), ex.TextCellValue(formatExpiryForExcel(u['expiryDate'])), ex.TextCellValue(uid), ex.TextCellValue((u['app_username']?? '').toString()), ex.TextCellValue((u['app_password']?? '').toString())]);
      }
      var bytes = excel.save();
      if (bytes!= null) {
        String fileName = 'users_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        if (kIsWeb) { await FilePicker.platform.saveFile(fileName: fileName, bytes: Uint8List.fromList(bytes)); } else { final dir = await getApplicationDocumentsDirectory(); final file = File('${dir.path}/$fileName'); await file.writeAsBytes(bytes); await OpenFile.open(file.path); }
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red)); }
    setState(() => isExcelLoading = false);
  }

  Future<void> importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (result == null) return;
      setState(() => isExcelLoading = true);
      Uint8List? bytes = kIsWeb? result.files.single.bytes : await File(result.files.single.path!).readAsBytes();
      if (bytes == null) throw "File read error";
      var excel = ex.Excel.decodeBytes(bytes);
      var table = excel.tables[excel.tables.keys.first]!;
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      int count = 0;
      for (int i = 1; i < table.rows.length; i++) {
        var row = table.rows[i]; if (row.isEmpty) continue;
        String pppoeUser = row[0]?.value?.toString().trim()?? ''; if (pppoeUser.isEmpty) continue;
        String pppoePass = row.length > 1? row[1]?.value?.toString().trim()?? '1234' : '1234';
        String profile = row.length > 2? row[2]?.value?.toString()?? '10 Mbps' : '10 Mbps';
        String expiration = row.length > 3? row[3]?.value?.toString()?? '' : '';
        String appUser = row.length > 5? row[5]?.value?.toString().trim()?? pppoeUser : pppoeUser;
        String appPass = row.length > 6? row[6]?.value?.toString().trim()?? pppoePass : pppoePass;
        int expiryMillis; try { expiryMillis = expiration.contains('-')? DateTime.parse(expiration).millisecondsSinceEpoch : DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch; } catch (e) { expiryMillis = DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch; }
        Map<String, dynamic> userData = {'name': pppoeUser, 'phone': pppoeUser, 'package': profile, 'amount': 1000, 'username': appUser, 'password': appPass, 'pppoe_username': pppoeUser, 'pppoe_password': pppoePass, 'app_username': appUser, 'app_password': appPass, 'isActive': true, 'createdAt': DateTime.now().millisecondsSinceEpoch, 'expiryDate': expiryMillis, 'expiry': expiration, 'pendingDue': 0};
        await _firestore.collection('isps').doc(uid).collection('my_users').doc(pppoeUser).set(userData, SetOptions(merge: true));
        widget.users.removeWhere((u) => u['phone'].toString() == pppoeUser); widget.users.add(userData); count++;
      }
      widget.onUsersUpdate(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count Users Imported"), backgroundColor: Colors.green));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Error: $e"), backgroundColor: Colors.red)); }
    setState(() => isExcelLoading = false);
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) { return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: ctrl, keyboardType: isNumber? TextInputType.number : TextInputType.text, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: Colors.white54), filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))); }
  Future<void> deleteUser(Map<String, dynamic> user) async { bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: Text("Delete?", style: GoogleFonts.poppins(color: Colors.white)), content: Text("Delete ${user['name']}?", style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes", style: TextStyle(color: Colors.red)))]))?? false; if (!confirm) return; try { String? uid = FirebaseAuth.instance.currentUser?.uid; await _firestore.collection('isps').doc(uid).collection('my_users').doc(user['phone'].toString()).delete(); setState(() => widget.users.removeWhere((u) => u['phone'].toString() == user['phone'].toString())); widget.onUsersUpdate(); } catch (e) {} }

  void showAddUserDialog({Map<String, dynamic>? editUser, int? editIndex}) {
    final nameCtrl = TextEditingController(text: editUser?['name']?? "");
    final phoneCtrl = TextEditingController(text: editUser?['phone']?? "");
    final cnicCtrl = TextEditingController(text: editUser?['cnic']?? ""); // POINT 8
    final addressCtrl = TextEditingController(text: editUser?['address']?? ""); // POINT 8
    final amountCtrl = TextEditingController(text: editUser?['amount']?.toString()?? "1000");
    final pppoeUserCtrl = TextEditingController(text: editUser?['pppoe_username']?? "");
    final pppoePassCtrl = TextEditingController(text: editUser?['pppoe_password']?? "");
    final appUserCtrl = TextEditingController(text: editUser?['app_username']?? "");
    final appPassCtrl = TextEditingController(text: editUser?['app_password']?? "");
    DateTime selectedExpiry = editUser?['expiryDate']!= null? DateTime.fromMillisecondsSinceEpoch(editUser!['expiryDate']) : calculateExpiry(DateTime.now());
    bool isSaving = false;
    String selectedPackage = editUser?['package']?? "10 Mbps"; // POINT 8
    List<String> packages = ["5 Mbps", "10 Mbps", "10 MB", "20 Mbps", "20 MB", "30 Mbps", "50 Mbps"];
    bool createCustomerLogin = editUser?['createCustomerLogin']?? false; // POINT 8

    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(editUser == null? "Add Customer" : "Edit Customer", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(child: Column(children: [
          _field(nameCtrl, "Name", Icons.person),
          _field(phoneCtrl, "Phone", Icons.phone),
          _field(cnicCtrl, "ID Card Number", Icons.badge),
          _field(addressCtrl, "Address", Icons.home),
          Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(value: packages.contains(selectedPackage)? selectedPackage : "10 Mbps", dropdownColor: Color(0xFF2A2A2A), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: "Package Select", prefixIcon: Icon(Icons.wifi, size: 18, color: Colors.white54), filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), items: packages.map((p)=> DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v)=> setDialogState(()=> selectedPackage = v!))),
          _field(amountCtrl, "Amount", Icons.money, isNumber: true),
          const SizedBox(height: 10),
          Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10), border: Border.all(color: isExpired({'expiryDate': selectedExpiry.millisecondsSinceEpoch})? Colors.red : Colors.white24)), child: Row(children: [Icon(Icons.calendar_today, size: 18, color: Colors.white54), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Expiry Date", style: TextStyle(color: Colors.white54, fontSize: 11)), Text(formatDate(selectedExpiry.millisecondsSinceEpoch), style: TextStyle(color: isExpired({'expiryDate': selectedExpiry.millisecondsSinceEpoch})? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold))])), TextButton(onPressed: () async { DateTime? picked = await showDatePicker(context: context, initialDate: selectedExpiry, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (context, child) => Theme(data: ThemeData.dark(), child: child!)); if (picked!= null) setDialogState(() => selectedExpiry = picked); }, child: Text("Change", style: TextStyle(color: Color(0xFF7C4DFF))))])),
          const Divider(color: Colors.white24),
          TextField(controller: pppoeUserCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: "PPPoE Username", filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), onChanged: (val){ if(appUserCtrl.text.isEmpty) setDialogState(()=> appUserCtrl.text = val); }),
          const SizedBox(height: 10),
          TextField(controller: pppoePassCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: "PPPoE Password", filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          CheckboxListTile(value: createCustomerLogin, onChanged: (v)=> setDialogState(()=> createCustomerLogin = v!), title: Text("Customer Login Banao?", style: TextStyle(color: Colors.white70, fontSize: 12)), activeColor: Color(0xFF7C4DFF), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: isSaving? null : () async { if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return; setDialogState(() => isSaving = true); try { String? uid = FirebaseAuth.instance.currentUser?.uid; String finalPppoeUser = pppoeUserCtrl.text.trim().isEmpty? phoneCtrl.text.trim() : pppoeUserCtrl.text.trim(); String finalPppoePass = pppoePassCtrl.text.trim().isEmpty? "1234" : pppoePassCtrl.text.trim(); String finalAppUser = appUserCtrl.text.trim().isEmpty? finalPppoeUser : appUserCtrl.text.trim(); String finalAppPass = appPassCtrl.text.trim().isEmpty? finalPppoePass : appPassCtrl.text.trim(); Map<String, dynamic> userData = {'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'cnic': cnicCtrl.text.trim(), 'address': addressCtrl.text.trim(), 'package': selectedPackage, 'amount': int.tryParse(amountCtrl.text.trim())?? 1000, 'username': finalAppUser, 'password': finalAppPass, 'pppoe_username': finalPppoeUser, 'pppoe_password': finalPppoePass, 'app_username': finalAppUser, 'app_password': finalAppPass, 'isActive': true, 'createdAt': editUser?['createdAt']?? DateTime.now().millisecondsSinceEpoch, 'expiryDate': selectedExpiry.millisecondsSinceEpoch, 'expiry': formatExpiryForExcel(selectedExpiry.millisecondsSinceEpoch), 'pendingDue': editUser?['pendingDue']?? 0, 'createCustomerLogin': createCustomerLogin}; await _firestore.collection('isps').doc(uid).collection('my_users').doc(phoneCtrl.text.trim()).set(userData, SetOptions(merge: true)); if(createCustomerLogin){ await _firestore.collection('customers').doc(finalAppUser).set({'email': finalAppUser, 'phone': phoneCtrl.text.trim(), 'name': nameCtrl.text.trim(), 'password': finalAppPass, 'createdAt': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true)); } if (editIndex!= null) { setState(() => widget.users[editIndex] = userData); } else { setState(() { widget.users.removeWhere((u) => u['phone'].toString() == userData['phone'].toString()); widget.users.add(userData); }); } widget.onUsersUpdate(); if (mounted) Navigator.pop(c); } catch (e) { setDialogState(() => isSaving = false); } }, child: Text(editUser == null? "Save" : "Update")),])));
  }

  void showUserDetails(Map<String, dynamic> user) {
    int pending = (user['pendingDue']?? 0) is int? user['pendingDue'] : int.tryParse(user['pendingDue'].toString())?? 0;
    bool expired = isExpired(user);
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: Text(user['name'], style: GoogleFonts.poppins(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Phone: ${user['phone']}", style: TextStyle(color: Colors.white70)),
      Text("CNIC: ${user['cnic']?? '-'}", style: TextStyle(color: Colors.white70)),
      Text("Address: ${user['address']?? '-'}", style: TextStyle(color: Colors.white70)),
      SizedBox(height: 6),
      Text("Package: ${user['package']?? '-'}", style: TextStyle(color: Colors.white70)),
      Text("Expiry: ${formatDate(user['expiryDate'])}", style: TextStyle(color: expired? Colors.redAccent : Colors.white70)),
      SizedBox(height: 6),
      if (pending > 0) Text("Due: $pending Rs", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)) else Text("No Due", style: TextStyle(color: Colors.greenAccent)),
      if (pending > 0) SizedBox(height: 12),
      if (pending > 0) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: () { Navigator.pop(c); collectDueAmount(user); }, icon: Icon(Icons.payments), label: Text("Collect Due")),
    ]), actions: [TextButton(onPressed: ()=> Navigator.pop(c), child: Text("Close"))]));
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filtered = widget.users.where((u) => u['name'].toString().toLowerCase().contains(search.toLowerCase()) || u['phone'].toString().contains(search)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        if(isFabOpen)...[
          ScaleTransition(scale: AlwaysStoppedAnimation(1.0), child: FloatingActionButton.small(heroTag: "import", backgroundColor: Colors.green, onPressed: (){ setState(()=> isFabOpen=false); importFromExcel(); }, child: const Icon(Icons.upload_file, color: Colors.white))),
          const SizedBox(height: 10),
          FloatingActionButton.small(heroTag: "export", backgroundColor: const Color(0xFF7C4DFF), onPressed: (){ setState(()=> isFabOpen=false); exportToExcel(); }, child: const Icon(Icons.download, color: Colors.white)),
          const SizedBox(height: 10),
          FloatingActionButton.small(heroTag: "add", backgroundColor: Colors.blue, onPressed: (){ setState(()=> isFabOpen=false); showAddUserDialog(); }, child: const Icon(Icons.person_add, color: Colors.white)),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(backgroundColor: const Color(0xFF7C4DFF), onPressed: () => setState(()=> isFabOpen=!isFabOpen), child: Icon(isFabOpen? Icons.close : Icons.add)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => search = v), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Search...", prefixIcon: const Icon(Icons.search, color: Colors.white54), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))))])),
        if (isExcelLoading) const LinearProgressIndicator(color: Color(0xFF7C4DFF)),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, i) {
          var u = filtered[i];
          bool expired = isExpired(u);
          int pending = (u['pendingDue']?? 0) is int? u['pendingDue'] : int.tryParse(u['pendingDue'].toString())?? 0;
          int amount = (u['amount']?? 1000) is int? u['amount'] : int.tryParse(u['amount'].toString())?? 1000;
          return Card(color: const Color(0xFF1E1E1E), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: ListTile(
            onTap: () => showUserDetails(Map<String, dynamic>.from(u)),
            leading: CircleAvatar(backgroundColor: expired? Colors.red : (pending > 0? Colors.amber : Colors.green), child: Text(u['name'].isNotEmpty? u['name'][0] : "U", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            title: Text(u['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${u['pppoe_username']?? u['phone']} | Bill: $amount | ${u['package']?? ''} | Exp: ${formatDate(u['expiryDate'])} ${expired? '(EXPIRED)' : ''}", style: TextStyle(color: expired? Colors.redAccent : Colors.white54, fontSize: 11)),
              if (pending > 0)
                Row(children: [
                  Container(margin: EdgeInsets.only(top: 4), padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber)), child: Text("Due: $pending Rs", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold))),
                  SizedBox(width: 6),
                  GestureDetector(onTap: () => collectDueAmount(Map<String, dynamic>.from(u)), child: Container(margin: EdgeInsets.only(top: 4), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)), child: Text("Collect", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                ])
              else
                Text("Paid", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
            ]),
            trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => showAddUserDialog(editUser: Map<String, dynamic>.from(u), editIndex: widget.users.indexOf(u))),
          ));
        }))
      ]),
    );
  }
}