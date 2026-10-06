import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mikrotik_service.dart';

class MikrotikSettingScreen extends StatefulWidget {
  const MikrotikSettingScreen({super.key});
  @override State<MikrotikSettingScreen> createState() => _MikrotikSettingScreenState();
}

class _MikrotikSettingScreenState extends State<MikrotikSettingScreen> {
  final ipCtrl = TextEditingController(); final userCtrl = TextEditingController(text: "admin"); final passCtrl = TextEditingController(); final portCtrl = TextEditingController(text: "80");
  bool loading = false; String status = "Connect nahi hua"; bool connected = false;

  @override void initState(){ super.initState(); _load(); }
  _load() async { var p = await SharedPreferences.getInstance(); setState((){ ipCtrl.text = p.getString('mt_ip')??""; userCtrl.text = p.getString('mt_user')??"admin"; passCtrl.text = p.getString('mt_pass')??""; portCtrl.text = p.getString('mt_port')??"80"; }); }

  test() async {
    if(ipCtrl.text.trim().isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("IP likho pehle"), backgroundColor: Colors.red)); return; }
    setState(()=> loading=true);
    var p = await SharedPreferences.getInstance();
    await p.setString('mt_ip', ipCtrl.text.trim()); await p.setString('mt_user', userCtrl.text.trim()); await p.setString('mt_pass', passCtrl.text.trim()); await p.setString('mt_port', portCtrl.text.trim());

    var result = await MikrotikService.testConnection();

    setState(()=> {loading=false, status= result['msg'], connected= result['ok']});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['msg']), backgroundColor: result['ok']? Colors.green: Colors.red));
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: Color(0xFF121212), appBar: AppBar(title: Text("Mikrotik Pro Control", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: Color(0xFF121212), iconTheme: IconThemeData(color: Colors.white)),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Container(padding: EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Icon(Icons.router, size: 50, color: Color(0xFF7C4DFF))), SizedBox(height: 10), Center(child: Text("RouterOS v7 REST API", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))), Center(child: Text("Winbox > IP > Services > www (80) enable karo", style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54))), SizedBox(height: 20),
          Text("Router IP", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), SizedBox(height: 6), TextField(controller: ipCtrl, decoration: InputDecoration(hintText: "192.168.88.1", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          SizedBox(height: 12), Text("Port", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), SizedBox(height: 6), TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "80", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          SizedBox(height: 12), Text("Username", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), SizedBox(height: 6), TextField(controller: userCtrl, decoration: InputDecoration(hintText: "admin", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          SizedBox(height: 12), Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)), SizedBox(height: 6), TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "Mikrotik Password", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          SizedBox(height: 16), Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: connected? Colors.green.withOpacity(0.12): Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: connected? Colors.green.withOpacity(0.3): Colors.red.withOpacity(0.3))), child: Row(children: [Icon(connected? Icons.check_circle: Icons.info, color: connected? Colors.green: Colors.red, size: 20), SizedBox(width: 8), Expanded(child: Text(status, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)))])),
          SizedBox(height: 20), SizedBox(width: double.infinity, height: 52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: loading?null:test, child: loading? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)): Text("Save & Real Test", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
          SizedBox(height: 10), Text("Note: RouterOS 6 hai to ye REST kaam nahi karega. RouterOS 7 update karo ya API port 8728 wala purana package use hoga.", style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45)),
        ]))
      ]),
    );
  }
}