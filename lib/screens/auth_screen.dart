import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoginMode = true;
  bool isIspMode = true; // true = ISP, false = Customer
  bool isOtpSent = false;
  bool loading = false;
  String generatedOtp = "";

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final otpCtrl = TextEditingController();

  final String companyEmail = "tauseefent8@gmail.com";
  final String appPassword = "enkwgxaohmygrnil";

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
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim()
      );

      String collectionName = isIspMode ? 'isps' : 'customers';
      await FirebaseFirestore.instance.collection(collectionName).doc(cred.user!.uid).set({
        'email': emailCtrl.text.trim(),
        'role': isIspMode ? 'isp' : 'customer',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // FIX: ID banne ke baad foran logout taake auto dashboard na khule
      await FirebaseAuth.instance.signOut();

      setState(() { isLoginMode = true; isOtpSent = false; loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Ban Gayi! Ab Login Karo")));

    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = e.message ?? "Error";
      if (e.code == 'email-already-in-use') msg = "Ye Gmail pehle se bani hui hai, Login karo";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  // FIX 4: YEHI WALA MASLA FIX KIYA - Ab logout ke baad usi ID se login hoga
  Future<void> login() async {
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email aur Password likho")));
      return;
    }
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim()
      );
      // Login success hoga to main.dart ka StreamBuilder khud MainNav pe le jayega

    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      String msg = "Login Fail: ${e.code}";
      if (e.code == 'user-not-found') msg = "Ye ID bani hui nahi hai, Pehle ID banao";
      if (e.code == 'wrong-password') msg = "Password galat hai";
      if (e.code == 'invalid-email') msg = "Email ka format galat hai";
      if (e.code == 'invalid-credential') msg = "Email ya Password galat hai";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi, size: 50, color: Color(0xFF7C4DFF)),
              const SizedBox(height: 10),
              const Text("Tauseef Enterprises", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(isLoginMode ? "Login Karo" : "Nayi ID Banao", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),

              // ISP / Customer Toggle
              Container(
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                      onTap: () => setState(() => isIspMode = true),
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isIspMode ? Colors.deepPurple : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          child: Text("ISP Login", textAlign: TextAlign.center, style: TextStyle(color: isIspMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold))
                      )
                  )),
                  Expanded(child: GestureDetector(
                      onTap: () => setState(() => isIspMode = false),
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: !isIspMode ? Colors.deepPurple : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          child: Text("Customer Login", textAlign: TextAlign.center, style: TextStyle(color: !isIspMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold))
                      )
                  )),
                ]),
              ),
              const SizedBox(height: 20),

              TextField(controller: emailCtrl, style: const TextStyle(color: Colors.black), decoration: InputDecoration(labelText: "${isIspMode ? 'ISP' : 'Customer'} Gmail ID", border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(labelText: "Password (6 harf)", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              if (!isLoginMode && isOtpSent)
                TextField(controller: otpCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(labelText: "OTP Code", border: OutlineInputBorder())),

              const SizedBox(height: 20),
              loading ? const CircularProgressIndicator() : SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      onPressed: () => isLoginMode ? login() : isOtpSent ? verifyAndCreate() : sendOtp(),
                      child: Text(isLoginMode ? "Login" : isOtpSent ? "Verify & Create ID" : "OTP Bhejo", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
              ),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => setState(() { isLoginMode = !isLoginMode; isOtpSent = false; }),
                  child: Text(isLoginMode ? "Naya Account Banana?" : "Pehle se ID hai? Login Pe Jao")
              )
            ]),
          ),
        ),
      ),
    );
  }
}