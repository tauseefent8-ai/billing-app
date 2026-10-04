import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class IspCreateAccountScreen extends StatefulWidget {
  const IspCreateAccountScreen({super.key});
  @override
  State<IspCreateAccountScreen> createState() => _IspCreateAccountScreenState();
}

class _IspCreateAccountScreenState extends State<IspCreateAccountScreen> {
  bool isOtpSent = false;
  bool isOtpVerified = false;
  bool loading = false;
  bool obscure = true;
  bool obscure2 = true;
  String generatedOtp = "";

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final otpCtrl = TextEditingController();

  final String companyEmail = "tauseefent8@gmail.com";
  final String appPassword = "enkwgxaohmygrnil";

  Timer? _timer;
  int _seconds = 0;
  bool canResend = false;

  void startTimer() {
    setState(() { _seconds = 30; canResend = false; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) { timer.cancel(); setState(() => canResend = true); }
      else { setState(() => _seconds--); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> sendOtp({bool isResend = false}) async {
    if (!emailCtrl.text.trim().contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sahi Gmail likho")));
      return;
    }
    setState(() { loading = true; generatedOtp = (100000 + Random().nextInt(900000)).toString(); });

    final smtpServer = gmail(companyEmail, appPassword);
    final message = Message()..from = Address(companyEmail, 'Tauseef Enterprises')..recipients.add(emailCtrl.text.trim())..subject = 'ISP OTP Code - $generatedOtp'..text = 'Aapka ISP OTP Code hai: $generatedOtp';
    try {
      await send(message, smtpServer);
      setState(() { isOtpSent = true; loading = false; });
      startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isResend ? "OTP Dobara Bhej Diya!" : "OTP bhej diya ${emailCtrl.text.trim()} pe")));
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Email Fail: $e")));
    }
  }

  void verifyOtp() {
    if (otpCtrl.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP")));
      return;
    }
    setState(() { isOtpVerified = true; });
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Verified! Ab Password Banao"), backgroundColor: Colors.green));
  }

  Future<void> createAccount() async {
    if (passCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password kam se kam 6 harf ka ho")));
      return;
    }
    if (passCtrl.text.trim() != confirmPassCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password match nahi kar raha")));
      return;
    }
    setState(() => loading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      await FirebaseFirestore.instance.collection('isps').doc(cred.user!.uid).set({
        'email': emailCtrl.text.trim(),
        'biz_name': 'Tauseef Enterprises',
        'role': 'isp',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ISP ID Ban Gayi! Ab Login Karo")));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = e.message ?? "Error";
      if (e.code == 'email-already-in-use') msg = "Ye Gmail pehle se bani hui hai";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)), title: Text("New ISP Account", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
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
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: const Color(0xFF7C4DFF), width: 2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.wifi, color: Color(0xFF7C4DFF))),
                  const SizedBox(width: 10),
                  Text("Billio - ISP Only", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ])),
                const SizedBox(height: 14),
                Center(child: Text(isOtpVerified ? "Create Password" : isOtpSent ? "Verify OTP" : "Create ISP Account", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                Center(child: Text(isOtpVerified ? "Ab apna password banao" : isOtpSent ? "Email pe OTP bheja gaya hai" : "Sirf ISP ke liye - OTP se Verify hogi", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54))),
                const SizedBox(height: 24),
                _label("ISP Gmail ID"),
                TextField(controller: emailCtrl, enabled: !isOtpSent, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "you@gmail.com", prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (isOtpSent && !isOtpVerified) ...[
                  const SizedBox(height: 14),
                  _label("OTP Code"),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "6 digit OTP", prefixIcon: const Icon(Icons.shield_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                if (isOtpVerified) ...[
                  const SizedBox(height: 14),
                  _label("Create Password"),
                  TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Min 6 characters", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                  const SizedBox(height: 14),
                  _label("Confirm Password"),
                  TextField(controller: confirmPassCtrl, obscureText: obscure2, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Password dobara likho", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure2 = !obscure2)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), onPressed: loading ? null : () { if (!isOtpSent) { sendOtp(); } else if (!isOtpVerified) { verifyOtp(); } else { createAccount(); } }, child: loading ? const CircularProgressIndicator(color: Colors.white) : Text(!isOtpSent ? "OTP Bhejo" : !isOtpVerified ? "Verify OTP" : "Create Account", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
                if (isOtpSent && !isOtpVerified) ...[
                  const SizedBox(height: 12),
                  Center(child: canResend ? TextButton(onPressed: loading ? null : () => sendOtp(isResend: true), child: Text("Resend OTP", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 13))) : Text("Resend OTP in $_seconds sec", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13))),
                ],
                const SizedBox(height: 8),
                Center(child: TextButton(onPressed: () => Navigator.pop(context), child: RichText(text: TextSpan(text: "Already have account? ", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13), children: [TextSpan(text: "Login", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 13))])))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)));
}