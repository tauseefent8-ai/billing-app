import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  bool loading = false;
  bool isOtpSent = false;
  bool isOtpVerified = false;
  String generatedOtp = "";
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
    try {
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).set({
        'otp': generatedOtp,
        'time': DateTime.now().millisecondsSinceEpoch,
        'email': emailCtrl.text.trim(),
        'type': 'customer_forgot'
      });
      setState(() { isOtpSent = true; loading = false; });
      startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isResend ? "OTP Dobara: $generatedOtp" : "Aapka OTP hai: $generatedOtp"), backgroundColor: Colors.green, duration: Duration(seconds: 8)));
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void verifyOtp() {
    if (otpCtrl.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP")));
      return;
    }
    setState(() => isOtpVerified = true);
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Verified! Ab Reset Email bhej diya jayega"), backgroundColor: Colors.green));
  }

  Future<void> resetPassword() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).delete();
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password Reset Email bhej diya hai ${emailCtrl.text.trim()} pe"), backgroundColor: Colors.green, duration: Duration(seconds: 6)));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)), title: Text("Forgot Password", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                TextField(controller: emailCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "Gmail", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                if(isOtpSent) ...[
                  TextField(controller: otpCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "OTP", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("Verify", style: TextStyle(color: Colors.white))),
                    SizedBox(width: 10),
                    if(canResend) TextButton(onPressed: ()=> sendOtp(isResend: true), child: Text("Resend")) else Text("$_seconds sec"),
                  ]),
                ],
                SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: loading? null : (){ if(!isOtpSent){ sendOtp(); } else if(!isOtpVerified){ verifyOtp(); } else { resetPassword(); } }, child: loading? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isOtpSent? (isOtpVerified? "Send Reset Email" : "Verify OTP") : "Send OTP", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}