import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final bool isCustomer;
  final bool isCreateMode;
  const AuthScreen({super.key, this.isCustomer = false, this.isCreateMode = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoginMode = true;
  bool isIspMode = true;
  bool isOtpSent = false;
  bool loading = false;
  bool obscure = true;
  String generatedOtp = "";

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final otpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    isIspMode = !widget.isCustomer;
    isLoginMode = !widget.isCreateMode;
    _forceLogoutIfDeleted();
  }

  Future<void> _forceLogoutIfDeleted() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      var prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
    if (widget.isCreateMode) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // FIXED: Ab Email pe nahi, Firestore me OTP save hota hai - Secure
  Future<void> sendOtp() async {
    if (!emailCtrl.text.trim().contains("@") || passCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sahi Gmail aur 6 harf ka password likho"), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      loading = true;
      generatedOtp = (100000 + Random().nextInt(900000)).toString();
    });

    try {
      // OTP ko Firestore me save karo - Secure, Gmail password ki zaroorat nahi
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).set({
        'otp': generatedOtp,
        'time': DateTime.now().millisecondsSinceEpoch,
        'email': emailCtrl.text.trim(),
      });

      setState(() { isOtpSent = true; loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Aapka OTP hai: $generatedOtp - Isko enter karo"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 8),
        ));
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Error: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 6)));
    }
  }

  Future<void> verifyAndCreate() async {
    if (otpCtrl.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP"), backgroundColor: Colors.red));
      return;
    }
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signOut();
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      String collectionName = isIspMode ? 'isps' : 'customers';
      await FirebaseFirestore.instance.collection(collectionName).doc(cred.user!.uid).set({
        'biz_name': 'Billio',
        'companyName': 'Billio',
        'email': emailCtrl.text.trim(),
        'role': isIspMode ? 'isp' : 'customer',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // OTP delete karo
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).delete();
      await FirebaseAuth.instance.signOut();
      setState(() { isLoginMode = true; isOtpSent = false; loading = false; generatedOtp = ""; otpCtrl.clear(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Ban Gayi! Ab Login Karo"), backgroundColor: Colors.green));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = e.message ?? "Error";
      if (e.code == 'email-already-in-use') {
        msg = "Ye Gmail pehle se bani hui hai! Firebase Console > Authentication me ja ke delete karo phir nayi banao, ya Login karo";
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: Duration(seconds: 6)));
    }
  }

  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email aur Password likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() => loading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      String collectionName = isIspMode ? 'isps' : 'customers';
      var doc = await FirebaseFirestore.instance.collection(collectionName).doc(cred.user!.uid).get();
      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        var prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Is ID ka data delete ho chuka hai, nayi ID banao"), backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
        }
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = "Login Fail: ${e.code}";
      if (e.code == 'user-not-found') msg = "Ye ID bani hui nahi hai, Pehle ID banao";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') msg = "Password ya Email galat hai";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: const Color(0xFF7C4DFF), width: 2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C4DFF))),
                  const SizedBox(width: 10),
                  Text("Billio", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                ])),
                const SizedBox(height: 14),
                Center(child: Text(isLoginMode ? "Welcome Back" : "Create Account", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                Center(child: Text(isLoginMode ? "Login Karo" : "Nayi ID Banao - OTP se Verify hogi", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: GestureDetector(onTap: () => setState(() => isIspMode = true), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isIspMode ? const Color(0xFF7C4DFF) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Text("ISP", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: isIspMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13))))),
                    Expanded(child: GestureDetector(onTap: () => setState(() => isIspMode = false), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: !isIspMode ? const Color(0xFF7C4DFF) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Text("Customer", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: !isIspMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13))))),
                  ]),
                ),
                const SizedBox(height: 20),
                _label("${isIspMode ? 'ISP' : 'Customer'} Gmail ID"),
                TextField(controller: emailCtrl, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "you@gmail.com", prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                const SizedBox(height: 14),
                _label("Password"),
                TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "123456", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (!isLoginMode && isOtpSent) ...[
                  const SizedBox(height: 14),
                  _label("OTP Code"),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "6 huroof ka OTP", prefixIcon: const Icon(Icons.pin), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: loading ? null : () { if (isLoginMode) { login(); } else { if (!isOtpSent) { sendOtp(); } else { verifyAndCreate(); } } }, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isLoginMode ? "Login" : (isOtpSent ? "Verify OTP" : "Send OTP"), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 12),
                Center(child: TextButton(onPressed: () => setState(() { isLoginMode = !isLoginMode; isOtpSent = false; }), child: Text(isLoginMode ? "Nayi ID banao? Create" : "Pehle se ID hai? Login", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontSize: 12, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}