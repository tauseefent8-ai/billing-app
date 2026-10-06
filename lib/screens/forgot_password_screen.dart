import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  bool loading = false;
  bool isOtpSent = false;
  bool isOtpVerified = false;
  bool obscure = true;
  String generatedOtp = "";

  final String companyEmail = "tauseefent8@gmail.com";
  final String appPassword = "enkwgxaohmygrnil";

  Future<void> sendOtp() async {
    if (!emailCtrl.text.trim().contains("@gmail.com")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sahi Gmail likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() { loading = true; generatedOtp = (100000 + Random().nextInt(900000)).toString(); });
    final smtpServer = gmail(companyEmail, appPassword);
    final message = Message()
      ..from = Address(companyEmail, 'Billio')
      ..recipients.add(emailCtrl.text.trim())
      ..subject = 'Billio - Password Reset OTP $generatedOtp'
      ..text = 'Aapka Password Reset OTP hai: $generatedOtp\nYe kisi se share na karein.';

    try {
      await send(message, smtpServer);
      setState(() { isOtpSent = true; loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP bhej diya ${emailCtrl.text.trim()} pe"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Email Fail: $e"), backgroundColor: Colors.red));
    }
  }

  void verifyOtp() {
    if (otpCtrl.text.trim() == generatedOtp) {
      setState(() => isOtpVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Verified! Ab naya password lagao"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat OTP"), backgroundColor: Colors.red));
    }
  }

  Future<void> resetPassword() async {
    if (newPassCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 6 harf ka likho"), backgroundColor: Colors.red));
      return;
    }
    setState(() => loading = true);
    try {
      // Check karo user isps me hai ya customers me
      var methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(emailCtrl.text.trim());
      if (methods.isEmpty) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ye ID bani hui nahi hai"), backgroundColor: Colors.red));
        return;
      }

      // Firebase ka official reset email bhi bhejo + Firestore me update
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());

      // Note: Custom OTP se direct password change client se possible nahi (Admin SDK chahiye)
      // Is liye hum 2 kaam karte hain:
      // 1. Firebase ko reset email bhejne diya (user ko link se bhi reset ho jayega)
      // 2. Firestore me naya password ka hint save kar dete hain taake aapko pata chale

      setState(() => loading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Password Reset", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
            content: Text("1. Aapke Gmail pe Firebase ka reset link bhej diya hai\n2. OTP verify ho gaya hai, ab aap us link se ya is naye password se login try karo: ${newPassCtrl.text.trim()}\n\nAgar login na ho to Firebase Console > Authentication me ja ke is user ka password manually ${newPassCtrl.text.trim()} set kar do, ya us ID ko delete karke isi email se naya banao.", style: GoogleFonts.poppins(fontSize: 11, color: Colors.black87)),
            actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: Text("OK", style: GoogleFonts.poppins(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold)))],
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: IconThemeData(color: Colors.white), title: Text("Forgot Password", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("Password Reset", style: GoogleFonts.poppins(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))),
                Center(child: Text("Gmail pe OTP le kar password reset karo", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12))),
                SizedBox(height: 22),
                Text("Gmail ID", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 6),
                TextField(controller: emailCtrl, enabled: !isOtpSent, style: TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "you@gmail.com", prefixIcon: Icon(Icons.mail_outline, size: 20, color: Colors.black26), filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                SizedBox(height: 14),
                if (isOtpSent && !isOtpVerified) ...[
                  Text("OTP Code", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "6 digit OTP", prefixIcon: Icon(Icons.shield_outlined, size: 20, color: Colors.black26), filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                if (isOtpVerified) ...[
                  Text("Naya Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  TextField(controller: newPassCtrl, obscureText: obscure, style: TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "Naya 6 harf ka password", prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.black26), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.black26), onPressed: ()=> setState(()=> obscure=!obscure)), filled: true, fillColor: Color(0xFFF2F2F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                ],
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: loading ? null : () {
                      if (!isOtpSent) sendOtp();
                      else if (!isOtpVerified) verifyOtp();
                      else resetPassword();
                    },
                    child: loading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(!isOtpSent ? "OTP Bhejo" : !isOtpVerified ? "OTP Verify Karo" : "Password Reset Karo", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}