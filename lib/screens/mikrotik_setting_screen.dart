import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mikrotik_service.dart';

class MikrotikSettingScreen extends StatefulWidget {
  const MikrotikSettingScreen({super.key});
  @override State<MikrotikSettingScreen> createState() => _MikrotikSettingScreenState();
}

class _MikrotikSettingScreenState extends State<MikrotikSettingScreen> {
  final ipCtrl = TextEditingController();
  final userCtrl = TextEditingController(text: "admin");
  final passCtrl = TextEditingController();
  final portCtrl = TextEditingController(text: "80");
  bool loading = false;
  String status = "Connect nahi hua";
  bool connected = false;

  @override void initState(){ super.initState(); _load(); }

  _load() async {
    var p = await SharedPreferences.getInstance();
    String ip = p.getString('mt_ip') ?? "";
    String user = p.getString('mt_user') ?? "admin";
    String pass = p.getString('mt_pass') ?? "";
    String port = p.getString('mt_port') ?? "80";

    ipCtrl.text = ip;
    userCtrl.text = user;
    passCtrl.text = pass;
    portCtrl.text = port;

    // FIX: setState se pehle direct value se service ko do
    MikrotikService.setCreds(ip: ip, port: port, username: user, password: pass);
    setState(() {});
  }

  test() async {
    if (ipCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP likho pehle"), backgroundColor: Colors.red));
      return;
    }

    String ip = ipCtrl.text.trim();
    String port = portCtrl.text.trim();
    String user = userCtrl.text.trim();
    String pass = passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User/Pass khali hai, ISP ka user/pass likho"), backgroundColor: Colors.red));
      return;
    }

    setState(() => loading = true);

    // FIX: Jo ISP likhega wahi MikroTik ko jayega - Save se PEHLE setCreds
    MikrotikService.setCreds(ip: ip, port: port, username: user, password: pass);

    var p = await SharedPreferences.getInstance();
    await p.setString('mt_ip', ip);
    await p.setString('mt_user', user);
    await p.setString('mt_pass', pass);
    await p.setString('mt_port', port);

    var result = await MikrotikService.testConnection();

    setState(() {
      loading = false;
      status = result['msg'];
      connected = result['ok'];
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['msg']), backgroundColor: result['ok'] ? Colors.green : Colors.red));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("Mikrotik Pro Control", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.router, size: 50, color: Color(0xFF7C4DFF))),
                const SizedBox(height: 10),
                Center(child: Text("RouterOS v7 REST API", style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                Center(child: Text("Winbox > IP > Services > www (80) enable karo", style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54))),
                const SizedBox(height: 20),
                Text("Router IP", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: ipCtrl, decoration: InputDecoration(hintText: "192.168.88.1", filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                Text("Port", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "80", filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                Text("Username", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: userCtrl, decoration: InputDecoration(hintText: "admin / bilal / koi bhi", filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "Mikrotik ka random Password", filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: connected ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: connected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(connected ? Icons.check_circle : Icons.info, color: connected ? Colors.green : Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(status, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: loading ? null : test,
                    child: loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Save & Real Test", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                Text("Note: Jo User/Pass yahan likhoge wahi MikroTik pe jayega. Ghalat hoga to RED 401 ayega.", style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45)),
              ],
            ),
          )
        ],
      ),
    );
  }
}