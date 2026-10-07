import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_screen.dart';

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

  // SECURE FIX: Gmail password hata diya, ab Firestore OTP use hoga

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

    try {
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).set({
        'otp': generatedOtp,
        'time': DateTime.now().millisecondsSinceEpoch,
        'email': emailCtrl.text.trim(),
      });
      setState(() { isOtpSent = true; isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kIsWeb ? "WEB MODE: Aapka OTP hai $generatedOtp" : "Aapka OTP hai $generatedOtp"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 8)
        ));
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Error: $e"), backgroundColor: Colors.red));
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
        await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).delete();
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
                TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "123456", prefixIcon: const Icon(Icons.lock_outline, color: Colors.black26, size: 20), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.black26), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (!isLogin && isOtpSent) ...[
                  const SizedBox(height: 14),
                  Text("OTP", style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "6 digits OTP", prefixIcon: const Icon(Icons.pin, color: Colors.black26, size: 20), filled: true, fillColor: const Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: isLoading ? null : handleAuth, child: isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isLogin ? "Login" : (isOtpSent ? "Verify & Create" : "Send OTP"), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 10),
                Center(child: TextButton(onPressed: ()=> setState(()=> isLogin = !isLogin), child: Text(isLogin ? "Account nahi hai? Create karo" : "Already ID hai? Login karo", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontSize: 12, fontWeight: FontWeight.bold)))),
                Center(child: TextButton(onPressed: forgotPass, child: Text("Password bhool gaye?", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 11)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}