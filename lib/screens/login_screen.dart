import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'isp_create_account_screen.dart';
import 'isp_forgot_password_screen.dart';
import 'customer_login_screen.dart'; // <-- YE CHANGE KIYA HAI

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;

  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email aur Password likho")));
      return;
    }
    setState(()=> loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(()=> loading = false);
      String msg = e.code == 'user-not-found' ? "ID nahi bani" : "Email/Password galat hai";
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
                Center(child: Text("ISP Login", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black))),
                Center(child: Text("Apni ISP ID se login karo", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54))),
                const SizedBox(height: 24),
                Text("Email", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 6),
                TextField(controller: emailCtrl, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "you@isp.com", prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                const SizedBox(height: 14),
                Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 6),
                TextField(controller: passCtrl, obscureText: obscure, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Password", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: ()=> setState(()=> obscure = !obscure)), filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),

                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const IspForgotPasswordScreen()));
                    },
                    child: Text("Forgot Password?", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),

                const SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), onPressed: loading ? null : login, child: loading ? const CircularProgressIndicator(color: Colors.white) : Text("Login", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 54, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => const IspCreateAccountScreen())); }, child: Text("New ISP? Create Account", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 14)))),
                const SizedBox(height: 10),
                // --- YAHAN FIX KIYA HAI ---
                SizedBox(width: double.infinity, height: 54, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black26, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerLoginScreen())); }, child: Text("Login as Customer", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}