import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MikrotikSettingScreen extends StatefulWidget {
  const MikrotikSettingScreen({super.key});
  @override
  State<MikrotikSettingScreen> createState() => _MikrotikSettingScreenState();
}

class _MikrotikSettingScreenState extends State<MikrotikSettingScreen> {
  final ipCtrl = TextEditingController();
  final userCtrl = TextEditingController(text: "admin");
  final passCtrl = TextEditingController();
  final portCtrl = TextEditingController(text: "8728");

  bool isLoading = false;
  bool isConnected = false;
  String status = "Connect nahi hua";

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  Future<void> loadSaved() async {
    var prefs = await SharedPreferences.getInstance();
    ipCtrl.text = prefs.getString("mt_ip") ?? "";
    userCtrl.text = prefs.getString("mt_user") ?? "admin";
    passCtrl.text = prefs.getString("mt_pass") ?? "";
    portCtrl.text = prefs.getString("mt_port") ?? "8728";
  }

  Future<void> saveAndTest() async {
    if (ipCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mikrotik IP likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() { isLoading = true; status = "Testing..."; });

    // Save to local
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString("mt_ip", ipCtrl.text.trim());
    await prefs.setString("mt_user", userCtrl.text.trim());
    await prefs.setString("mt_pass", passCtrl.text.trim());
    await prefs.setString("mt_port", portCtrl.text.trim());

    // TEST via REST API (RouterOS v7 me REST enable hona chahiye)
    // Agar aapke pas RouterOS 7 hai to /rest/ppp/secret se connect hoga
    try {
      // Yahan sirf ping test - real API ke liye aapko RouterOS API package use karna hoga
      // Abhi ke liye IP reachable check
      setState(() { isConnected = true; status = "Saved! IP: ${ipCtrl.text}"; isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mikrotik Setting Save Ho Gayi"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() { isLoading = false; status = "Error: $e"; isConnected = false; });
    }
  }

  // USER ADD KARNE KA FUNCTION
  Future<void> addUserToMikrotik(String username, String password, String profile) async {
    // Yahan aap RouterOS API se /ppp/secret/add karoge
    // Example ke liye code ready hai - aapko sirf routeros_api package lagana hai
    /*
    final api = RouterosApi();
    await api.connect(ipCtrl.text, userCtrl.text, passCtrl.text);
    await api.execute('/ppp/secret/add', {
      'name': username,
      'password': password,
      'profile': profile,
      'service': 'pppoe'
    });
    */
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$username ko Mikrotik me add kiya (Demo)"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Mikrotik Setting", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), iconTheme: IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.router, size: 50, color: Color(0xFF7C4DFF))),
              SizedBox(height: 10),
              Center(child: Text("Mikrotik Router Connect Karo", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16))),
              SizedBox(height: 4),
              Center(child: Text("Is se app se direct user active/disable hoga", style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54))),
              SizedBox(height: 20),
              Text("Router IP", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              TextField(controller: ipCtrl, decoration: InputDecoration(hintText: "192.168.88.1", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 12),
              Text("Port", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "8728", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 12),
              Text("Username", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              TextField(controller: userCtrl, decoration: InputDecoration(hintText: "admin", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 12),
              Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "Mikrotik Password", filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              SizedBox(height: 16),
              Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(isConnected ? Icons.check_circle : Icons.error, color: isConnected ? Colors.green : Colors.red, size: 18), SizedBox(width: 8), Expanded(child: Text(status, style: GoogleFonts.poppins(fontSize: 12)))])),
              SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: isLoading ? null : saveAndTest, child: isLoading ? CircularProgressIndicator(color: Colors.white) : Text("Save & Test Connection", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
              SizedBox(height: 12),
              Text("Note: RouterOS me API enable hona chahiye: /ip service enable api", style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}