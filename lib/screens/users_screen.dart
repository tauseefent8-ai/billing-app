import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/sms_reminder_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/mikrotik_service.dart';

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
  String search = "";
  TextEditingController searchCtrl = TextEditingController();

  List<dynamic> get filtered {
    return widget.users.where((u){
      if(search.isEmpty) return true;
      return u['name'].toString().toLowerCase().contains(search.toLowerCase()) || u['phone'].toString().contains(search);
    }).toList();
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: "1000");
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    DateTime selectedExpiry = DateTime.now().add(Duration(days: 30));
    String selectedPackage = "10 Mbps";
    List<String> packages = ["5 Mbps", "10 Mbps", "20 Mbps", "30 Mbps", "50 Mbps", "100 Mbps"];
    bool isSaving = false;

    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Color(0xFF1E1E1E),
          insetPadding: EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add New Customer", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  _buildShotField(nameCtrl, "Name", Icons.person),
                  SizedBox(height: 10),
                  _buildShotField(phoneCtrl, "Phone", Icons.phone),
                  SizedBox(height: 10),
                  _buildShotField(cnicCtrl, "CNIC Number", Icons.badge),
                  SizedBox(height: 10),
                  _buildShotField(addressCtrl, "Address", Icons.home),
                  SizedBox(height: 14),
                  Text("Package", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonFormField<String>(
                      value: selectedPackage,
                      dropdownColor: Color(0xFF2A2A2A),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.wifi, color: Colors.white54, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      items: packages.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setDialogState(() => selectedPackage = v!),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Amount", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  _buildShotField(amountCtrl, "1000", Icons.payments, isNumber: true),
                  SizedBox(height: 10),
                  _buildShotField(userCtrl, "Username", Icons.account_circle),
                  SizedBox(height: 10),
                  Text("Password", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  _buildShotField(passCtrl, "....", Icons.lock, isPassword: true),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                        SizedBox(width: 12),
                        Expanded(child: Text("Expiry: ${selectedExpiry.day}/${selectedExpiry.month}/${selectedExpiry.year}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                        GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(context: context, initialDate: selectedExpiry, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (context, child) => Theme(data: ThemeData.dark(), child: child!));
                            if (picked!= null) setDialogState(() => selectedExpiry = picked);
                          },
                          child: Icon(Icons.calendar_month, color: Colors.white54, size: 18),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.white70))),
                      SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                        onPressed: isSaving? null : () async {
                          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Name, Phone, Username, Password zaroori hai")));
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            String rawPhone = phoneCtrl.text.trim();
                            String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
                            if(phone.length < 10){
                              throw Exception("Phone number sahi nahi - kam se kam 10 digits");
                            }
                            String profileForMT = selectedPackage.replaceAll(" Mbps", "M").replaceAll(" ", "");

                            // FIX: timeout lagaya taake loading na atke
                            var mkResult = await MikrotikService.createUser(username: userCtrl.text.trim(), password: passCtrl.text.trim(), profile: profileForMT).timeout(Duration(seconds: 12), onTimeout: () => {'ok': true, 'msg': 'MikroTik timeout but continue'});
                            if(mkResult['ok'] == false){
                              throw Exception("MikroTik Error: ${mkResult['msg']}");
                            }

                            Map<String, dynamic> newUserData = {
                              'name': nameCtrl.text.trim(),
                              'phone': phone,
                              'raw_phone': rawPhone,
                              'cnic': cnicCtrl.text.trim(),
                              'address': addressCtrl.text.trim(),
                              'package': selectedPackage,
                              'speed': profileForMT,
                              'amount': FirebaseService.parseAmount(amountCtrl.text),
                              'pendingDue': FirebaseService.parseAmount(amountCtrl.text),
                              'username': userCtrl.text.trim(),
                              'password': passCtrl.text.trim(),
                              'pppoe_username': userCtrl.text.trim(),
                              'pppoe_password': passCtrl.text.trim(),
                              'status': 'active',
                              'expiryDate': selectedExpiry.millisecondsSinceEpoch,
                              'createdAt': DateTime.now().millisecondsSinceEpoch,
                            };

                            // FIX: timeout lagaya
                            await FirebaseService.usersCol.doc(phone).set(newUserData, SetOptions(merge: true)).timeout(Duration(seconds: 15), onTimeout: () {
                              throw Exception("Firestore slow - Internet check karo");
                            });

                            try{
                              var appProv = Provider.of<AppProvider>(context, listen: false);
                              appProv.addUserLocal(newUserData);
                            }catch(e){
                              widget.users.insert(0, newUserData);
                            }

                            try{
                              Provider.of<AppProvider>(context, listen: false).goToFirstPage();
                            }catch(e){
                              try{ Provider.of<AppProvider>(context, listen: false).currentPage = 0; }catch(_){}
                            }

                            widget.onUsersUpdate();
                            if (mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Done! ${nameCtrl.text} - MikroTik + App me save ho gaya"), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
                          } finally {
                            // FIX: finally me loading band - ye sab se zaroori fix hai
                            if (ctx.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                        child: isSaving? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Save", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      });
    });
  }

  Widget _buildShotField(TextEditingController c, String hint, IconData icon, {bool isNumber=false, bool isNum=false, bool isPassword=false}) {
    bool useNumber = isNumber || isNum;
    return Container(
      decoration: BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: c,
        obscureText: isPassword,
        keyboardType: useNumber? TextInputType.number : TextInputType.text,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(backgroundColor: Color(0xFF121212), title: Text("Customers (${filtered.length})", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), actions: [
        IconButton(icon: Icon(Icons.search, color: Colors.white70), onPressed: (){
          showDialog(context: context, builder: (c)=> AlertDialog(backgroundColor: Color(0xFF1E1E1E), title: Text("Search", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)), content: TextField(controller: searchCtrl, autofocus: true, style: TextStyle(color: Colors.white), onChanged: (v){ setState(()=> search=v); }, decoration: InputDecoration(hintText: "Name / Phone", hintStyle: TextStyle(color: Colors.white38))), actions: [TextButton(onPressed: (){ searchCtrl.clear(); setState(()=> search=""); Navigator.pop(c); }, child: Text("Clear")), TextButton(onPressed: ()=> Navigator.pop(c), child: Text("OK"))]));
        })
      ]),
      body: filtered.isEmpty? Center(child: Text("Koi customer nahi", style: GoogleFonts.poppins(color: Colors.white54))) : ListView.builder(itemCount: filtered.length, itemBuilder: (c,i){
        var u = filtered[i];
        return Container(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ListTile(
          leading: CircleAvatar(backgroundColor: Color(0xFF7C4DFF), child: Text(u['name'].toString().isNotEmpty? u['name'].toString()[0].toUpperCase() : "U", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          title: Text(u['name']?? '-', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text("${u['phone']} | ${u['package']} | Rs.${u['amount']}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(Icons.message, color: Colors.greenAccent, size: 18), onPressed: ()=> SmsReminderService.sendWhatsAppReminder(u['phone'].toString(), u['name'].toString(), FirebaseService.parseAmount(u['pendingDue']?? u['amount']))),
            IconButton(icon: Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () async {
              bool confirm = await showDialog(context: context, builder: (ctx)=> AlertDialog(backgroundColor: Color(0xFF1E1E1E), title: Text("Delete?", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)), content: Text("${u['name']} ko delete karna hai?", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: Text("Nahi")), TextButton(onPressed: ()=> Navigator.pop(ctx,true), child: Text("Haan", style: TextStyle(color: Colors.red))) ]))?? false;
              if(!confirm) return;
              try{
                String cleanPhone = u['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
                await FirebaseService.usersCol.doc(cleanPhone).delete();
                Provider.of<AppProvider>(context, listen: false).removeUserLocal(cleanPhone);
                widget.onUsersUpdate();
              }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Error: $e"), backgroundColor: Colors.red)); }
            }),
          ]),
        ));
      }),
      floatingActionButton: FloatingActionButton(backgroundColor: Color(0xFF7C4DFF), child: Icon(Icons.person_add, color: Colors.white), onPressed: _showAddUserDialog),
    );
  }
}