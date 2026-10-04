import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_dashboard.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});
  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLoading = false;
  bool obscure = true;

  Future<void> loginCustomer() async {
    setState(()=> isLoading = true);
    try {
      String u = userCtrl.text.trim();
      String p = passCtrl.text.trim();
      if(u.isEmpty || p.isEmpty) throw "Username aur Password likho";

      var firestore = FirebaseFirestore.instance;
      var query = await firestore.collection('app_logins').where('username', isEqualTo: u).where('password', isEqualTo: p).get();
      if(query.docs.isNotEmpty){
        var data = query.docs.first.data();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'customer');
        await prefs.setString('isp_id', data['isp_id']);
        await prefs.setString('customer_phone', data['phone']);
        if(!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CustomerDashboard(phone: data['phone'], ispId: data['isp_id'])));
      } else { throw "Ghalat Username/Password - ISP se rabta karen"; }
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
    setState(()=> isLoading = false);
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
                Center(child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF7C4DFF).withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.person_outline, size: 40, color: const Color(0xFF7C4DFF)))),
                const SizedBox(height: 14),
                Center(child: Text("Customer Login", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black))),
                const SizedBox(height: 6),
                Center(child: Text("ISP se mila hua Username / Password", style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center,)),
                const SizedBox(height: 28),

                Text("Username", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: userCtrl,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "e.g. customer_123",
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true, fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.black54), onPressed: ()=> setState(()=> obscure = !obscure)),
                    filled: true, fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: isLoading ? null : loginCustomer,
                    child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("Login", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                // YEH NAYA BUTTON HAI - ISP LOGIN PAR WAPIS JANE KE LIYE
                SizedBox(
                  width: double.infinity, height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                    onPressed: (){
                      Navigator.pop(context); // Wapis ISP login par
                    },
                    child: Text("Login as ISP", style: GoogleFonts.poppins(color: const Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 15)),
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