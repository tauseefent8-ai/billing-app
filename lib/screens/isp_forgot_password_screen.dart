import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IspForgotPasswordScreen extends StatefulWidget {
  const IspForgotPasswordScreen({super.key});
  @override
  State<IspForgotPasswordScreen> createState() => _IspForgotPasswordScreenState();
}

class _IspForgotPasswordScreenState extends State<IspForgotPasswordScreen> {
  bool isOtpSent = false;
  bool isOtpVerified = false;
  bool loading = false;
  bool obscure = true;
  bool obscure2 = true;
  String generatedOtp = "";

  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

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
    setState(() => loading = true);
    try {
      var check = await FirebaseFirestore.instance.collection('isps').where('email', isEqualTo: emailCtrl.text.trim()).get();
      if (check.docs.isEmpty) {
        setState(()=> loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ye Gmail se koi ISP ID nahi bani hui"), backgroundColor: Colors.red));
        return;
      }
      String otp = (100000 + Random().nextInt(900000)).toString();
      setState(()=> generatedOtp = otp);
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).set({
        'otp': otp,
        'time': DateTime.now().millisecondsSinceEpoch,
        'email': emailCtrl.text.trim(),
        'type': 'forgot'
      });
      setState(() { isOtpSent = true; loading = false; });
      startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isResend ? "OTP Dobara: $otp" : "Aapka OTP hai: $otp"), backgroundColor: Colors.green, duration: Duration(seconds: 8)));
    } catch (e) {
      setState(()=> loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void verifyOtp() {
    if (otpCtrl.text.trim() != generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP")));
      return;
    }
    setState(() { isOtpVerified = true; });
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Verified! Ab Naya Password Banao"), backgroundColor: Colors.green));
  }

  Future<void> resetPassword() async {
    if (passCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 6 harf ka likho")));
      return;
    }
    if (passCtrl.text.trim() != confirmPassCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password match nahi")));
      return;
    }
    setState(()=> loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).delete();
      setState(()=> loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password Reset Email bhej diya hai ${emailCtrl.text.trim()} pe - Check karo"), backgroundColor: Colors.green, duration: Duration(seconds: 6)));
      Navigator.pop(context);
    } catch (e) {
      setState(()=> loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)), title: Text("Forgot Password", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Text("Password Bhool Gaye?", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 16),
                TextField(controller: emailCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "Apni Gmail Likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                if(isOtpSent)...[
                  TextField(controller: otpCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "OTP", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("Verify", style: TextStyle(color: Colors.white))),
                    SizedBox(width: 10),
                    if(canResend) TextButton(onPressed: ()=> sendOtp(isResend: true), child: Text("Resend")) else Text("$_seconds sec", style: TextStyle(fontSize: 12)),
                  ]),
                  if(isOtpVerified)...[
                    SizedBox(height: 12),
                    Text("Ab aapko email pe password reset ka link bhej diya jayega", style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
                  ]
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