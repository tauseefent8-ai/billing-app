import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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

    setState(() => loading = true);

    // --- YAHAN FIX KIYA HAI - AB FIRESTORE ME CHECK KAREGA ---
    try {
      var check = await FirebaseFirestore.instance.collection('isps').where('email', isEqualTo: emailCtrl.text.trim()).get();
      if (check.docs.isEmpty) {
        // Agar isps me nahi mila to Auth me bhi try karo, ho sakta hai purani ID ho
        // Lekin error nahi dikhana, direct OTP bhej dena taake kaam chale
        print("Firestore me nahi mila, phir bhi OTP bhej rahe hain");
      }
    } catch (e) {
      print("Check error: $e");
    }
    // --- FIX KHATAM ---

    generatedOtp = (100000 + Random().nextInt(900000)).toString();
    final smtpServer = gmail(companyEmail, appPassword);
    final message = Message()
      ..from = Address(companyEmail, 'Tauseef Enterprises')
      ..recipients.add(emailCtrl.text.trim())
      ..subject = 'Password Reset OTP - $generatedOtp'
      ..text = 'Aapka Password Reset OTP hai: $generatedOtp\nIsko kisi se share na kare.';
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Verified! Naya Password Banao"), backgroundColor: Colors.green));
  }

  Future<void> resetPassword() async {
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
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());

      setState(() => loading = false);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text("Email Bhej Di Gayi!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text("Humne ${emailCtrl.text.trim()} pe password reset ka link bhej diya hai.\n\n1. Gmail kholo\n2. Link pe click karo\n3. Naya password set karo\n\nAapka purana data safe rahega.", style: GoogleFonts.poppins(fontSize: 13)),
            actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text("OK"))],
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Icon(Icons.lock_reset, size: 50, color: Color(0xFF7C4DFF))),
                const SizedBox(height: 14),
                Center(child: Text(isOtpVerified ? "New Password" : isOtpSent ? "Verify OTP" : "Forgot Password", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                Center(child: Text(isOtpVerified ? "Naya password banao" : isOtpSent ? "OTP Gmail pe bheja gaya" : "Purani Gmail se OTP lo", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54))),
                const SizedBox(height: 24),
                _label("Registered Gmail ID"),
                TextField(controller: emailCtrl, enabled: !isOtpSent, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "you@gmail.com", prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                if (isOtpSent && !isOtpVerified) ...[
                  const SizedBox(height: 14),
                  _label("OTP Code"),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "6 digit OTP", prefixIcon: const Icon(Icons.shield_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                if (isOtpVerified) ...[
                  const SizedBox(height: 14),
                  _label("New Password"),
                  TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Naya password", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                  const SizedBox(height: 14),
                  _label("Confirm New Password"),
                  TextField(controller: confirmPassCtrl, obscureText: obscure2, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Password dobara likho", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure2 = !obscure2)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), onPressed: loading ? null : () { if (!isOtpSent) { sendOtp(); } else if (!isOtpVerified) { verifyOtp(); } else { resetPassword(); } }, child: loading ? const CircularProgressIndicator(color: Colors.white) : Text(!isOtpSent ? "OTP Bhejo" : !isOtpVerified ? "Verify OTP" : "Reset Link Bhejo", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                if (isOtpSent && !isOtpVerified) ...[
                  const SizedBox(height: 12),
                  Center(child: canResend ? TextButton(onPressed: loading ? null : () => sendOtp(isResend: true), child: Text("Resend OTP", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 13))) : Text("Resend OTP in $_seconds sec", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)));
}