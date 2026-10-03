import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatefulWidget {
  final List users;
  final List bills;
  final VoidCallback onUsersUpdate;
  final VoidCallback onBillsUpdate;

  UsersScreen({required this.users, required this.bills, required this.onUsersUpdate, required this.onBillsUpdate});

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String currentIspId = "";
  List filteredUsers = [];

  @override
  void initState() {
    super.initState();
    getIspId();
  }

  void getIspId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentIspId = prefs.getString('isp_id') ?? "bilal_isp";
      // Sirf isi ISP ke users filter karo
      filteredUsers = widget.users.where((u) => (u['isp_id'] ?? "bilal_isp") == currentIspId).toList();
    });
  }

  void addUserDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pkgCtrl = TextEditingController(text: "10 Mbps");
    final amountCtrl = TextEditingController(text: "1500");
    DateTime expiry = DateTime.now().add(Duration(days: 30));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text("Naya Customer Add Karo", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: phoneCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Phone (Username banega)", labelStyle: TextStyle(color: Colors.white54)), keyboardType: TextInputType.phone),
              TextField(controller: pkgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Package", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: amountCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Monthly Amount", labelStyle: TextStyle(color: Colors.white54)), keyboardType: TextInputType.number),
              SizedBox(height: 10),
              Text("Expiry: ${expiry.day}/${expiry.month}/${expiry.year}", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)),
            onPressed: () async {
              if(nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;

              var newUser = {
                "name": nameCtrl.text.trim(),
                "phone": phoneCtrl.text.trim(),
                "package": pkgCtrl.text.trim(),
                "amount": int.tryParse(amountCtrl.text) ?? 1500,
                "expiry": expiry.toIso8601String(),
                "isActive": true,
                "isp_id": currentIspId, // YEH SAB SE IMPORTANT HAI
                "createdAt": DateTime.now().millisecondsSinceEpoch,
              };

              // 1. Local list me add
              setState(() {
                widget.users.add(newUser);
                filteredUsers = widget.users.where((u) => (u['isp_id'] ?? currentIspId) == currentIspId).toList();
              });

              // 2. Firebase 'users' me save
              try {
                await FirebaseFirestore.instance.collection('users').doc(newUser['phone'].toString()).set(newUser);

                // 3. Customer ka Login banao - app_logins me
                await FirebaseFirestore.instance.collection('app_logins').doc(newUser['phone'].toString()).set({
                  'username': newUser['phone'],
                  'password': '1234', // Default password, baad me customer change kar sakta hai
                  'role': 'customer',
                  'isp_id': currentIspId,
                  'phone': newUser['phone'],
                  'name': newUser['name'],
                });

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Customer + Login Ban Gaya! Username: ${newUser['phone']} Pass: 1234")));
              } catch(e){
                print("Firebase error: $e");
              }

              widget.onUsersUpdate();
              Navigator.pop(context);
            },
            child: Text("Add Customer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Har bar filter update karo
    filteredUsers = widget.users.where((u) => (u['isp_id'] ?? currentIspId) == currentIspId || (u['isp_id'] == null && currentIspId == "bilal_isp")).toList();

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: filteredUsers.isEmpty
          ? Center(child: Text("Koi Customer nahi hai\nIs ISP ke liye naya add karo", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))
          : ListView.builder(
        itemCount: filteredUsers.length,
        itemBuilder: (context, i){
          var u = filteredUsers[i];
          return Card(
            color: Color(0xFF1E1E1E),
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Color(0xFF7C4DFF), child: Icon(Icons.person, color: Colors.white)),
              title: Text(u['name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${u['phone']} - ${u['package']}", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text("Login: ${u['phone']} / 1234", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                ],
              ),
              trailing: Text("Rs ${u['amount']}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF7C4DFF),
        onPressed: addUserDialog,
        child: Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}