import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mikrotik_setting_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/offline_service.dart';
import '../services/export_service.dart';
import '../services/firebase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String bizName = "";
  String dueDate = "10";
  String waTemplate = "";
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState(){
    super.initState();
    _loadInfo();
  }

  _loadInfo() async {
    final p = await SharedPreferences.getInstance();
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    String firebaseName = "";
    try{
      if(uid!=null){
        var doc = await _firestore.collection('isps').doc(uid).get();
        if(doc.exists){
          firebaseName = doc.data()?['biz_name']?? doc.data()?['companyName']?? "";
        }
      }
    }catch(e){}
    setState(() {
      bizName = firebaseName.isNotEmpty? firebaseName : (p.getString('biz_name')?? "ISP PENNEL");
      dueDate = p.getString('bill_due_date')?? "10";
      waTemplate = p.getString('wa_template')?? "Salam {name}, aapka {package} ka bill Rs.{amount} hai.";
    });
  }

  void _showCostDialog() {
    showDialog(context: context, builder: (ctx) => const PackageCostDialog());
  }

  void _showBusinessDialog() {
    showDialog(context: context, builder: (ctx) => const BusinessInfoDialog()).then((_)=> _loadInfo());
  }

  void _showDueDateDialog() {
    TextEditingController c = TextEditingController(text: dueDate);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Bill Due Date", style: TextStyle(color: Colors.white)),
      content: TextField(controller: c, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Har mahine kis tareekh ko bill due ho? (1-28)", labelStyle: TextStyle(color: Colors.white54))),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setString('bill_due_date', c.text); _loadInfo(); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))
      ],
    ));
  }

  void _showWADialog() {
    TextEditingController c = TextEditingController(text: waTemplate);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("WhatsApp Template", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Message...", hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        const Text("{name}, {amount}, {package} use kar sakte hain", style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setString('wa_template', c.text); _loadInfo(); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))
      ],
    ));
  }

  // FIXED: ExportService.exportToExcel(context, users, bills, collections) - aap ke service ke mutabiq
  void _showImportExportDialog() {
    showDialog(context: context, builder: (ctx){
      return AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Import / Export Customers", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Users screen se button hata diya hai (STEP 3). Ab sirf yahan se Import/Export hoga.", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(Icons.upload_file, size: 16), label: Text("Export Excel (Users+Bills+Collections)", style: GoogleFonts.poppins(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async {
            Navigator.pop(ctx);
            try {
              var prov = Provider.of<AppProvider>(context, listen: false);
              await ExportService.exportToExcel(context, prov.users, prov.bills, prov.collections);
            } catch (e) {
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red));
            }
          })),
          SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(Icons.download, size: 16), label: Text("Import Customers CSV", style: GoogleFonts.poppins(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () async {
            Navigator.pop(ctx);
            _showImportDialog();
          })),
          SizedBox(height: 8),
          Text("STEP 10: Final - Import ke baad users inactive save honge, MikroTik pe tab banenge jab Active karo (STEP 1).", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8)),
        ]),
        actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text("Close"))],
      );
    });
  }

  void _showImportDialog() {
    TextEditingController csvCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx){
      return AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Import CSV", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
        content: SizedBox(width: 300, height: 300, child: Column(children: [
          Text("CSV format: name,phone,package,amount,username,password", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9)),
          SizedBox(height: 8),
          Expanded(child: TextField(controller: csvCtrl, maxLines: 15, style: TextStyle(color: Colors.white, fontSize: 10), decoration: InputDecoration(border: OutlineInputBorder(), hintText: "name,phone,package,amount,username,password\nAli,03001234567,10 Mbps,1000,ali123,1234", hintStyle: TextStyle(color: Colors.white24, fontSize: 9)))),
        ])),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async {
            String csv = csvCtrl.text.trim();
            if(csv.isEmpty) return;
            Navigator.pop(ctx);
            try {
              List<String> lines = csv.split("\n");
              int count = 0;
              for(var line in lines){
                if(line.trim().isEmpty) continue;
                List<String> parts = line.split(",");
                if(parts.length < 6) continue;
                String name = parts[0].trim();
                String rawPhone = parts[1].trim();
                String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
                String pkg = parts[2].trim();
                String amount = parts[3].trim();
                String username = parts[4].trim();
                String password = parts[5].trim();
                String profile = pkg.replaceAll(" Mbps", "M").replaceAll(" ", "");
                var newUser = {
                  'name': name,
                  'phone': phone,
                  'raw_phone': rawPhone,
                  'package': pkg,
                  'speed': profile,
                  'amount': FirebaseService.parseAmount(amount),
                  'pendingDue': FirebaseService.parseAmount(amount),
                  'username': username,
                  'password': password,
                  'pppoe_username': username,
                  'pppoe_password': password,
                  'status': 'disabled',
                  'expiryDate': DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                };
                await FirebaseService.usersCol.doc(phone).set(newUser, SetOptions(merge: true));
                try {
                  Provider.of<AppProvider>(context, listen: false).addUserLocal(newUser);
                } catch(_){}
                count++;
              }
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count users import ho gaye - Inactive (MikroTik pe Active par banenge)"), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
            } catch (e) {
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import Error: $e"), backgroundColor: Colors.red));
            }
          }, child: Text("Import")),
        ],
      );
    });
  }

  void _showBackupDialog() async {
    final p = await SharedPreferences.getInstance();
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, dynamic> allData = {};
    allData['bills'] = p.getString('bills_$uid');
    allData['collections'] = p.getString('collections_$uid');
    allData['customers'] = p.getString('users_data_$uid');
    allData['pkg_cost'] = p.getString('pkg_cost');
    allData['biz_name'] = p.getString('biz_name');
    allData['biz_phone'] = p.getString('biz_phone');
    String jsonStr = jsonEncode(allData);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Backup & Restore", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(icon: const Icon(Icons.copy), label: const Text("Backup Copy Karo"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () { Clipboard.setData(ClipboardData(text: jsonStr)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Copy Ho Gaya! WhatsApp par save kar lo"))); }),
        const SizedBox(height: 15),
        const Text("Restore karne ke liye neeche backup paste karein:", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        TextField(maxLines: 5, style: const TextStyle(color: Colors.white, fontSize: 10), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Backup JSON yahan paste karein", hintStyle: TextStyle(color: Colors.white38)), onChanged: (val) async { if(val.length > 100){ try{ Map<String, dynamic> data = jsonDecode(val); final pref = await SharedPreferences.getInstance(); if(data['bills']!=null) await pref.setString('bills_$uid', data['bills']); if(data['collections']!=null) await pref.setString('collections_$uid', data['collections']); if(data['customers']!=null) await pref.setString('users_data_$uid', data['customers']); if(data['pkg_cost']!=null) await pref.setString('pkg_cost', data['pkg_cost']); if(data['biz_name']!=null) await pref.setString('biz_name', data['biz_name']); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restore Ho Gaya! App restart karein"))); } catch(e){} } }),
      ])),
      actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Close"))],
    ));
  }

  Future<void> logoutWithSave() async {
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (c)=> AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          title: Text('Logout Karna Hai?', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Aapka sara data Firebase me save ho raha hai, 3 second lagega. Logout karna hai?', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c,false), child: Text('Nahi')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: ()=> Navigator.pop(c,true), child: Text('Haan Logout Karo', style: GoogleFonts.poppins(color: Colors.white))),
          ],
        )
    );
    if(confirm!=true) return;
    bool dialogOpen = true;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c)=> Dialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                const SizedBox(height: 16),
                Text('Save ho raha hai...', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Firebase me data save ho raha hai, 3 second intezar karo', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
        )
    );
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if(uid!=null){
        await _firestore.collection('isps').doc(uid).set({
          'biz_name': bizName,
          'companyName': bizName,
          'lastLogout': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge:true)).timeout(Duration(seconds: 8), onTimeout: () {
          throw Exception("Save timeout - continue logout");
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('biz_name', bizName.isEmpty? "ISP PENNEL" : bizName);
      }
      await Future.delayed(const Duration(seconds: 1));
    } catch(e){
      debugPrint("Logout save error (ignored): $e");
    } finally {
      if(dialogOpen && mounted){
        try{ Navigator.pop(context); dialogOpen = false; } catch(_){}
      }
      try{ await OfflineService.clearAll().timeout(Duration(seconds: 3)); }catch(_){}
      try{
        if(mounted){
          var prov = Provider.of<AppProvider>(context, listen: false);
          prov.users = [];
          prov.bills = [];
          prov.collections = [];
          prov.currentPage = 0;
          prov.notifyListeners();
        }
      }catch(_){}
      try{ await FirebaseAuth.instance.signOut().timeout(Duration(seconds: 5), onTimeout: (){}); } catch(e){ try{ await FirebaseAuth.instance.signOut(); } catch(_){} }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text("Settings - Final STEP 10", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), backgroundColor: const Color(0xFF121212), iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildTitle("NETWORKING"),
          _buildTile(Icons.router, "Mikrotik Control", "Router se users add / active / disable karo", (){ Navigator.push(context, MaterialPageRoute(builder: (_) => const MikrotikSettingScreen())); }, color: Colors.orange),
          const Divider(color: Colors.white12),
          _buildTitle("BUSINESS"),
          _buildTile(Icons.store, "Business Info", bizName.isEmpty? "ISP PENNEL" : bizName, _showBusinessDialog),
          _buildTile(Icons.attach_money, "Package Cost (Kharid Rate)", "Profit sahi nikalne ke liye - STEP 9", _showCostDialog, color: Colors.green),
          const Divider(color: Colors.white12),
          _buildTitle("BILLING - Due System (STEP 4,5)"),
          _buildTile(Icons.calendar_today, "Bill Due Date", "Har mah $dueDate tareekh ko due", _showDueDateDialog),
          _buildTile(Icons.message, "WhatsApp Template", waTemplate.isEmpty? "Default message" : waTemplate.substring(0, waTemplate.length>30?30:waTemplate.length), _showWADialog),
          _buildTile(Icons.receipt_long, "Bill Detail Logic", "Full Pay Active / Partial 300/400/600 / Active Without Pay + PDF - STEP 4", (){}, color: Colors.blue),
          _buildTile(Icons.account_balance_wallet, "Due Logic", "Kam paise par Due, agle month Due+Monthly=Total, Full pay par next sirf Monthly - STEP 5", (){}, color: Colors.orange),
          const Divider(color: Colors.white12),
          _buildTitle("CUSTOMERS - Import/Export (STEP 3 moved here)"),
          _buildTile(Icons.swap_vert, "Import / Export Customers", "Users screen se hata ke sirf yahan - STEP 3 + STEP 10", _showImportExportDialog, color: Colors.purple),
          const Divider(color: Colors.white12),
          _buildTitle("AUTO SYSTEM (STEP 2,7)"),
          _buildTile(Icons.auto_mode, "Auto Bill + Auto Disconnect", "Expire user ka bill auto + MikroTik auto disconnect - STEP 2,7", (){}, color: Colors.redAccent),
          _buildTile(Icons.dashboard, "Dashboard Summary", "Active/Disabled/Expired/AutoDisconnected + Partial/Pending - STEP 8", (){}, color: Colors.teal),
          _buildTile(Icons.bar_chart, "Reports & Profit", "Due Breakdown + Package Cost Profit - STEP 9", (){}, color: Colors.green),
          const Divider(color: Colors.white12),
          _buildTitle("APP"),
          _buildTile(Icons.backup, "Backup & Restore", "Data mehfooz rakhein", _showBackupDialog),
          _buildTile(Icons.info, "App Version - FINAL STEP 10", "v1.0 - All Steps 1-10 Done", (){}),
          const Divider(color: Colors.white12),
          _buildTitle("ACCOUNT"),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.logout, color: Colors.redAccent)),
              title: Text("Logout", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Firebase save + local clear", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
              onTap: logoutWithSave,
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTitle(String t){
    return Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text(t, style: GoogleFonts.poppins(color: Color(0xFF7C4DFF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)));
  }

  Widget _buildTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = Colors.white}){
    return Card(
      color: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class PackageCostDialog extends StatefulWidget {
  const PackageCostDialog({super.key});
  @override
  State<PackageCostDialog> createState() => _PackageCostDialogState();
}

class _PackageCostDialogState extends State<PackageCostDialog> {
  Map<String, TextEditingController> controllers = {};
  List<String> pkgs = ["5 Mbps", "10 Mbps", "20 Mbps", "30 Mbps", "50 Mbps", "100 Mbps"];
  Map<String, String> defaultCosts = {"5 Mbps": "400", "10 Mbps": "680", "20 Mbps": "950", "30 Mbps": "1350", "50 Mbps": "1800", "100 Mbps": "2500"};

  @override
  void initState(){
    super.initState();
    for(var p in pkgs){
      controllers[p] = TextEditingController(text: defaultCosts[p]?? "0");
    }
    _load();
  }

  _load() async {
    final pref = await SharedPreferences.getInstance();
    String? saved = pref.getString('pkg_cost');
    if(saved!=null){
      try{
        Map<String, dynamic> map = jsonDecode(saved);
        setState(() {
          map.forEach((k,v){
            if(controllers.containsKey(k)){
              controllers[k]!.text = v.toString();
            }
          });
        });
      }catch(_){}
    }
  }

  @override
  Widget build(BuildContext context){
    return AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("Package Cost (Kharid Rate)", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(children: pkgs.map((p)=> Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 80, child: Text(p, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11))), SizedBox(width: 10), Expanded(child: TextField(controller: controllers[p], keyboardType: TextInputType.number, style: TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(prefixText: "Rs. ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)) )) ]))).toList())),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async {
          final pref = await SharedPreferences.getInstance();
          Map<String, dynamic> map = {};
          controllers.forEach((k,v){ map[k] = double.tryParse(v.text)?? 0; });
          await pref.setString('pkg_cost', jsonEncode(map));
          if(mounted) Navigator.pop(context);
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Package Cost Save Ho Gaya"), backgroundColor: Colors.green));
        }, child: Text("Save"))
      ],
    );
  }
}

class BusinessInfoDialog extends StatefulWidget {
  const BusinessInfoDialog({super.key});
  @override
  State<BusinessInfoDialog> createState() => _BusinessInfoDialogState();
}

class _BusinessInfoDialogState extends State<BusinessInfoDialog> {
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController phoneCtrl = TextEditingController();
  @override
  void initState(){
    super.initState();
    _load();
  }
  _load() async {
    final p = await SharedPreferences.getInstance();
    nameCtrl.text = p.getString('biz_name')?? "";
    phoneCtrl.text = p.getString('biz_phone')?? "";
  }
  @override
  Widget build(BuildContext context){
    return AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("Business Info", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Business Name", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
        SizedBox(height: 10),
        TextField(controller: phoneCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Phone", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async {
          final p = await SharedPreferences.getInstance();
          await p.setString('biz_name', nameCtrl.text);
          await p.setString('biz_phone', phoneCtrl.text);
          String? uid = FirebaseAuth.instance.currentUser?.uid;
          if(uid!=null){
            await FirebaseFirestore.instance.collection('isps').doc(uid).set({'biz_name': nameCtrl.text, 'biz_phone': phoneCtrl.text, 'companyName': nameCtrl.text}, SetOptions(merge: true));
          }
          if(mounted) Navigator.pop(context);
        }, child: Text("Save"))
      ],
    );
  }
}