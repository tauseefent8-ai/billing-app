import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'forgot_password_screen.dart'; // <-- YE ADD KIYA HAI

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();
  bool isLoading = false;
  bool isLogin = true;
  bool obscure = true;
  bool isOtpSent = false;
  String generatedOtp = "";

  final String companyEmail = "tauseefent8@gmail.com";
  final String appPassword = "enkwgxaohmygrnil";

  Future<void> sendOtp() async {
    if (!emailCtrl.text.trim().contains("@gmail.com")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sirf Gmail ID likho ( @gmail.com )"), backgroundColor: Colors.red));
      return;
    }
    if (passCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 6 harf ka likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() {
      isLoading = true;
      generatedOtp = (100000 + Random().nextInt(900000)).toString();
    });
    final smtpServer = gmail(companyEmail, appPassword);
    final message = Message()
      ..from = Address(companyEmail, 'Billio')
      ..recipients.add(emailCtrl.text.trim())
      ..subject = 'Billio OTP - $generatedOtp'
      ..text = 'Aapka OTP hai: $generatedOtp';

    try {
      await send(message, smtpServer);
      setState(() { isOtpSent = true; isLoading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP bhej diya ${emailCtrl.text.trim()} pe"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Fail: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 6)));
    }
  }

  Future<void> handleAuth() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email / Password likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        var cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        var doc = await FirebaseFirestore.instance.collection('isps').doc(cred.user!.uid).get();
        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Is ID ka data delete ho chuka hai"), backgroundColor: Colors.orange));
        }
      } else {
        if (!isOtpSent) {
          setState(() => isLoading = false);
          await sendOtp();
          return;
        }
        if (otpCtrl.text.trim() != generatedOtp) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP"), backgroundColor: Colors.red));
          return;
        }
        await FirebaseAuth.instance.signOut();
        var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        await FirebaseFirestore.instance.collection('isps').doc(cred.user!.uid).set({
          'biz_name': 'Billio',
          'companyName': 'Billio',
          'email': emailCtrl.text.trim(),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'verified': true,
        });
        await FirebaseAuth.instance.signOut();
        setState(() { isLogin = true; isOtpSent = false; generatedOtp = ""; otpCtrl.clear(); });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Ban Gayi! Ab Login Karo"), backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Error";
      if (e.code == 'email-already-in-use') msg = "Ye Gmail pehle se bani hai, Login karo";
      if (e.code == 'user-not-found') msg = "ID nahi mili, pehle Create karo";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = "Password galat hai";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> deleteAllFirebaseData() async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.white, title: Text("Sab Delete?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)), actions: [TextButton(onPressed: ()=> Navigator.pop(c,false), child: Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: ()=> Navigator.pop(c,true), child: Text("Delete"))])) ?? false;
    if(!confirm) return;
    setState(()=> isLoading=true);
    try{
      var firestore = FirebaseFirestore.instance;
      var ispsSnap = await firestore.collection('isps').get();
      for(var ispDoc in ispsSnap.docs){
        for(String col in ['my_users','my_bills','my_collections','my_expenses']){
          var subSnap = await ispDoc.reference.collection(col).get();
          for(var d in subSnap.docs){ await d.reference.delete(); }
        }
        await ispDoc.reference.delete();
      }
      var prefs = await SharedPreferences.getInstance(); await prefs.clear();
      await FirebaseAuth.instance.signOut();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SARA DATA DELETE HO GAYA"), backgroundColor: Colors.green));
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)); }
    if(mounted) setState(()=> isLoading=false);
  }

  // YAHAN CHANGE KIYA HAI - AB NAYI SCREEN KHULEGI
  Future<void> forgotPass() async {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const ForgotPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF7C4DFF), width: 2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C4DFF), size: 22)),
                  const SizedBox(width: 10),
                  Text("Billio", style: GoogleFonts.poppins(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                ])),
                const SizedBox(height: 18),
                Center(child: Text(isLogin ? "ISP Login" : "Create Account - OTP Verify", style: GoogleFonts.poppins(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Center(child: Text(isLogin ? "Apni ISP ID se login karo" : "OTP se verify hoga tab hi ID banegi", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 11))),
                const SizedBox(height: 22),
                Text("Email", style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: emailCtrl, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "you@gmail.com", hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600), prefixIcon: const Icon(Icons.mail_outline, color: Colors.black26, size: 20), filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                const SizedBox(height: 14),
                Text("Password", style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "Password", hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600), prefixIcon: const Icon(Icons.lock_outline, color: Colors.black26, size: 20), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black26, size: 20), onPressed: () => setState(() => obscure = !obscure)), filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (!isLogin && isOtpSent) ...[
                  const SizedBox(height: 14),
                  Text("OTP Code", style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "6 digit OTP", prefixIcon: const Icon(Icons.shield_outlined, color: Colors.black26, size: 20), filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: forgotPass, child: Text("Forgot Password?", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontSize: 12, fontWeight: FontWeight.w600)))),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), onPressed: isLoading ? null : handleAuth, child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isLogin ? "Login" : isOtpSent ? "Verify & Create ID" : "OTP Bhejo", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 52, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () => setState(() { isLogin = !isLogin; isOtpSent = false; }), child: Text(isLogin ? "New ISP? Create Account" : "Already have account? Login", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.w600, fontSize: 13)))),
                const SizedBox(height: 14),
                Divider(color: Colors.black12),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 52, child: OutlinedButton(style: OutlinedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.08), side: const BorderSide(color: Colors.red, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: isLoading ? null : deleteAllFirebaseData, child: Text("ARZI - Sab IDs & Data Delete Karo", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}