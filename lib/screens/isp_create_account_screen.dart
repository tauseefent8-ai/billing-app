import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // FIXED: Ab Firestore me OTP save hota hai, Gmail password nahi chahiye
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).set({
        'otp': generatedOtp,
        'time': DateTime.now().millisecondsSinceEpoch,
        'email': emailCtrl.text.trim(),
      });
      setState(() { isOtpSent = true; loading = false; });
      startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isResend ? "OTP Dobara: $generatedOtp" : "Aapka OTP hai: $generatedOtp"), backgroundColor: Colors.green, duration: Duration(seconds: 8)));
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Error: $e"), backgroundColor: Colors.red));
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
      await FirebaseFirestore.instance.collection('email_otps').doc(emailCtrl.text.trim()).delete();
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Create ISP Account", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 16),
                TextField(controller: emailCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "Gmail", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                SizedBox(height: 12),
                if(isOtpSent)...[
                  TextField(controller: otpCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "OTP Enter Karo", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("Verify OTP", style: TextStyle(color: Colors.white))),
                    SizedBox(width: 10),
                    if(canResend) TextButton(onPressed: ()=> sendOtp(isResend: true), child: Text("Resend OTP")) else Text("Resend in $_seconds sec", style: TextStyle(fontSize: 12)),
                  ]),
                ],
                SizedBox(height: 12),
                if(isOtpVerified || !isOtpSent)...[
                  TextField(controller: passCtrl, obscureText: obscure, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "Password", suffixIcon: IconButton(icon: Icon(obscure? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> obscure=!obscure)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 12),
                  TextField(controller: confirmPassCtrl, obscureText: obscure2, style: TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "Confirm Password", suffixIcon: IconButton(icon: Icon(obscure2? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> obscure2=!obscure2)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                ],
                SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: loading? null : (){ if(!isOtpSent){ sendOtp(); } else if(!isOtpVerified){ verifyOtp(); } else { createAccount(); } }, child: loading? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isOtpSent? (isOtpVerified? "Create Account" : "Verify OTP") : "Send OTP", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}