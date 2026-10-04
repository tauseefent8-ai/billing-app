import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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

  final String companyEmail = "tauseefent8@gmail.com";
  final String appPassword = "enkwgxaohmygrnil"; // اس کو بعد میں ENV میں ڈالنا

  @override
  void initState() {
    super.initState();
    isIspMode = !widget.isCustomer;
    isLoginMode = !widget.isCreateMode;
  }

  Future<void> sendOtp() async {
    if (!emailCtrl.text.trim().contains("@") || passCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sahi Gmail aur 6 harf ka password likho")));
      return;
    }
    setState(() {
      loading = true;
      generatedOtp = (100000 + Random().nextInt(900000)).toString();
    });

    final smtpServer = gmail(companyEmail, appPassword);
    final message = Message()
      ..from = Address(companyEmail, 'Tauseef Enterprises')
      ..recipients.add(emailCtrl.text.trim())
      ..subject = 'OTP Code - $generatedOtp'
      ..text = 'Aapka OTP Code hai: $generatedOtp';

    try {
      await send(message, smtpServer);
      setState(() { isOtpSent = true; loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP bhej diya ${emailCtrl.text.trim()} pe")));
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Email Fail: $e")));
    }
  }

  Future<void> verifyAndCreate() async {
    if (otpCtrl.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP")));
      return;
    }
    setState(() => loading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(), password: passCtrl.text.trim());

      // ہر ISP کا اپنا ڈاکومنٹ بنے گا isps/{uid}
      String collectionName = isIspMode ? 'isps' : 'customers';
      await FirebaseFirestore.instance.collection(collectionName).doc(cred.user!.uid).set({
        'email': emailCtrl.text.trim(),
        'role': isIspMode ? 'isp' : 'customer',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();
      setState(() { isLoginMode = true; isOtpSent = false; loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Ban Gayi! Ab Login Karo")));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = e.message ?? "Error";
      if (e.code == 'email-already-in-use') msg = "Ye Gmail pehle se bani hui hai, Login karo";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email aur Password likho")));
      return;
    }
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(), password: passCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = "Login Fail: ${e.code}";
      if (e.code == 'user-not-found') msg = "Ye ID bani hui nahi hai, Pehle ID banao";
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = "Password galat hai";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

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
                TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Min 6 characters", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (!isLoginMode && isOtpSent) ...[
                  const SizedBox(height: 14),
                  _label("OTP Code"),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "6 digit OTP", prefixIcon: const Icon(Icons.shield_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), onPressed: loading ? null : () => isLoginMode ? login() : isOtpSent ? verifyAndCreate() : sendOtp(), child: loading ? const CircularProgressIndicator(color: Colors.white) : Text(isLoginMode ? "Login" : isOtpSent ? "Verify & Create ID" : "OTP Bhejo", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
                const SizedBox(height: 12),
                Center(child: TextButton(onPressed: () => setState(() { isLoginMode = !isLoginMode; isOtpSent = false; }), child: Text(isLoginMode ? "Naya Account Banana? Click Karo" : "Pehle se ID hai? Login Pe Jao", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.w600, fontSize: 13)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)));
}