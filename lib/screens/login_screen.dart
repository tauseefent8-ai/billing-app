import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'customer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLoading = false;
  String selectedRole = "isp";

  Future<void> loginWithGmail() async {
    setState(()=> isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if(googleUser == null) { setState(()=> isLoading=false); return; }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      String uid = userCred.user!.uid;
      String email = userCred.user!.email ?? "";
      String name = userCred.user!.displayName ?? "ISP";

      var firestore = FirebaseFirestore.instance;
      var ispDoc = await firestore.collection('isps').doc(uid).get();
      if(!ispDoc.exists){
        await firestore.collection('isps').doc(uid).set({
          'uid': uid,
          'email': email,
          'name': name,
          'role': 'isp',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('role', 'isp');
      await prefs.setString('isp_id', uid);
      await prefs.setString('isp_email', email);
      await prefs.setString('isp_name', name);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainNav()));
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(()=> isLoading = false);
  }

  Future<void> loginCustomer() async {
    setState(()=> isLoading = true);
    try {
      String u = userCtrl.text.trim();
      String p = passCtrl.text.trim();
      var firestore = FirebaseFirestore.instance;
      var query = await firestore.collection('app_logins').where('username', isEqualTo: u).where('password', isEqualTo: p).get();
      if(query.docs.isNotEmpty){
        var data = query.docs.first.data();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'customer');
        await prefs.setString('isp_id', data['isp_id']);
        await prefs.setString('customer_phone', data['phone']);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerDashboard(phone: data['phone'], ispId: data['isp_id'])));
      } else { throw "Ghalat Username/Password"; }
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
    setState(()=> isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi, size: 70, color: Color(0xFF7C4DFF)),
              const SizedBox(height: 10),
              Text("Bilal Wifi - SaaS", style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("ISP apne Gmail se login karega", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: ChoiceChip(label: const Text("ISP"), selected: selectedRole=="isp", selectedColor: const Color(0xFF7C4DFF), onSelected: (v){setState(()=> selectedRole="isp");})),
                  const SizedBox(width: 10),
                  Expanded(child: ChoiceChip(label: const Text("Customer"), selected: selectedRole=="customer", selectedColor: const Color(0xFF7C4DFF), onSelected: (v){setState(()=> selectedRole="customer");})),
                ],
              ),
              const SizedBox(height: 25),
              if(selectedRole == "isp") ...[
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isLoading ? null : loginWithGmail,
                    icon: const Icon(Icons.email, color: Colors.red),
                    label: isLoading ? const CircularProgressIndicator() : Text("Continue with Gmail", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                TextField(controller: userCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Phone", filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password 1234", filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: isLoading ? null : loginCustomer, child: const Text("LOGIN AS CUSTOMER", style: TextStyle(color: Colors.white)))),
              ]
            ],
          ),
        ),
      ),
    );
  }
}