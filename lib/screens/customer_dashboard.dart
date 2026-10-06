import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  Map<String,dynamic>? customerData;
  List<dynamic> myBills = [];
  List<dynamic> myCollections = [];
  bool loading = true;

  @override
  void initState(){ super.initState(); loadCustomer(); }

  Future<void> loadCustomer() async {
    setState(()=> loading=true);
    try{
      String email = FirebaseAuth.instance.currentUser?.email?? "";
      String phone = FirebaseAuth.instance.currentUser?.phoneNumber?? "";
      // Har ISP me search karo - simple logic
      var isps = await FirebaseFirestore.instance.collection('isps').get();
      for(var ispDoc in isps.docs){
        var usersSnap = await ispDoc.reference.collection('my_users').where('email', isEqualTo: email).get();
        if(usersSnap.docs.isEmpty && phone.isNotEmpty){
          usersSnap = await ispDoc.reference.collection('my_users').where('phone', isEqualTo: phone).get();
        }
        if(usersSnap.docs.isNotEmpty){
          customerData = usersSnap.docs.first.data();
          var billsSnap = await ispDoc.reference.collection('my_bills').where('phone', isEqualTo: customerData!['phone'].toString()).get();
          var colSnap = await ispDoc.reference.collection('my_collections').where('phone', isEqualTo: customerData!['phone'].toString()).get();
          myBills = billsSnap.docs.map((d)=> d.data()).toList();
          myCollections = colSnap.docs.map((d)=> d.data()).toList();
          break;
        }
      }
    }catch(e){ debugPrint("Customer load error $e"); }
    setState(()=> loading=false);
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))));
    if(customerData==null) return Scaffold(backgroundColor: Color(0xFF121212), appBar: AppBar(backgroundColor: Color(0xFF121212), title: Text("Customer", style: GoogleFonts.poppins(color: Colors.white))), body: Center(child: Text("Aapka data nahi mila, Admin se rabta karo\n${FirebaseAuth.instance.currentUser?.email}", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white54))));

    bool isExpired = false;
    if(customerData!['expiryDate']!=null){ try{ if(DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(customerData!['expiryDate']))) isExpired=true; }catch(e){} }

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(backgroundColor: Color(0xFF121212), title: Text("Welcome ${customerData!['name']}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), actions: [IconButton(icon: Icon(Icons.logout, color: Colors.white70), onPressed: () async { await FirebaseAuth.instance.signOut(); })]),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: isExpired? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: isExpired? Colors.red : Colors.green)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customerData!['name'].toString(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text("Phone: ${customerData!['phone']} | Package: ${customerData!['package']}", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 6),
          Text("Status: ${isExpired? "EXPIRE" : "ACTIVE"} | Due: Rs.${customerData!['pendingDue']??0}", style: GoogleFonts.poppins(color: isExpired? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          if(customerData!['expiryDate']!=null) Text("Expiry: ${DateTime.fromMillisecondsSinceEpoch(customerData!['expiryDate']).toString().substring(0,10)}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
        ])),
        SizedBox(height: 16),
        Text("Mere Pending Bills (${myBills.length})", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ...myBills.map((b)=> Container(margin: EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Icon(Icons.receipt, color: Colors.orange), title: Text("Rs.${b['amount']} - ${b['billMonth']}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), subtitle: Text(b['package'].toString(), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10))))),
        SizedBox(height: 16),
        Text("Meri Wasooli History (${myCollections.length})", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ...myCollections.map((c)=> Container(margin: EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text("Rs.${c['amount']} Jama - ${c['billMonth']}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), subtitle: Text(c['date'].toString().substring(0,10), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10))))),
      ]),
    );
  }
}