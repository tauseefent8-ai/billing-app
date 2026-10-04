import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/login_screen.dart';
import 'screens/customer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyProApp());
}

class MyProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212)),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (authSnap.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('isps').doc(authSnap.data!.uid).get(),
              builder: (context, ispDoc) {
                if (ispDoc.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (ispDoc.data!= null && ispDoc.data!.exists) {
                  return MainNav();
                }
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('customers').doc(authSnap.data!.uid).get(),
                  builder: (context, custDoc) {
                    if (custDoc.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (custDoc.data!= null && custDoc.data!.exists) {
                      return CustomerDashboard(phone: custDoc.data!['email']?? '', ispId: 'default');
                    }
                    return MainNav();
                  },
                );
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  @override
  _MainNavState createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;
  List<dynamic> allBills = [];
  List<dynamic> allUsers = [];
  List<dynamic> allCollections = [];
  String bizName = "Tauseef Enterprises";
  String bizPhone = "";
  final _firestore = FirebaseFirestore.instance;
  bool isLoadingData = true;
  final List<String> titles = ["Dashboard", "Bills", "Users", "Reports", "Settings"];

  @override
  void initState() { super.initState(); loadAllData(); }

  void loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => isLoadingData = false); return; }
    try {
      var ispDoc = await _firestore.collection('isps').doc(uid).get();
      if (ispDoc.exists) { bizName = ispDoc.data()?['biz_name']?? "Tauseef Enterprises"; bizPhone = ispDoc.data()?['biz_phone']?? ""; }

      var usersSnap = await _firestore.collection('isps').doc(uid).collection('my_users').get();
      var billsSnap = await _firestore.collection('isps').doc(uid).collection('my_bills').get();
      var colSnap = await _firestore.collection('isps').doc(uid).collection('my_collections').get();

      allUsers = usersSnap.docs.map((d) => d.data()).toList();
      var tempBills = billsSnap.docs.map((d) => d.data()).toList();
      var tempCols = colSnap.docs.map((d) => d.data()).toList();

      List<dynamic> validBills = [];
      List<String> billsToDeleteIds = [];
      for(var bill in tempBills){
        bool userExists = allUsers.any((u) => u['phone'].toString() == bill['phone'].toString());
        if(userExists){
          validBills.add(bill);
        } else {
          String phone = bill['phone']?.toString()?? "unknown";
          String month = bill['billMonth']?.toString()?? "";
          String created = bill['createdAt']?.toString()?? "";
          String id = "${phone}_${month}_$created".replaceAll('/', '_');
          billsToDeleteIds.add(id);
        }
      }
      allBills = validBills;

      Map<String, dynamic> colMap = {};
      for(var col in tempCols){
        String id = col['id']?.toString()?? "";
        if(id.isNotEmpty) colMap[id] = col;
      }
      allCollections = colMap.values.toList();

      for(var delId in billsToDeleteIds){
        await _firestore.collection('isps').doc(uid).collection('my_bills').doc(delId).delete();
      }

      setState(() { isLoadingData = false; });
      prefs.setString('users_data_$uid', json.encode(allUsers));
      prefs.setString('bills_$uid', json.encode(allBills));
      prefs.setString('collections_$uid', json.encode(allCollections));
      checkAndGenerateAutoBills();
    } catch (e) {
      final billsData = prefs.getString('bills_$uid');
      final usersData = prefs.getString('users_data_$uid');
      final colsData = prefs.getString('collections_$uid');
      setState(() {
        if (billsData!= null) try { allBills = json.decode(billsData); } catch(_){}
        if (usersData!= null) try { allUsers = json.decode(usersData); } catch(_){}
        if (colsData!= null) try { allCollections = json.decode(colsData); } catch(_){}
        allBills.removeWhere((b) =>!allUsers.any((u) => u['phone'].toString() == b['phone'].toString()));
        isLoadingData = false;
      });
      checkAndGenerateAutoBills();
    }
  }

  void saveBills() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance(); prefs.setString('bills_$uid', json.encode(allBills));
      for (var b in allBills) {
        String phone = b['phone']?.toString()?? "unknown";
        String month = b['billMonth']?.toString()?? "${DateTime.now().year}-${DateTime.now().month}";
        String created = b['createdAt']?.toString()?? DateTime.now().millisecondsSinceEpoch.toString();
        String id = "${phone}_${month}_$created".replaceAll('/', '_');
        await _firestore.collection('isps').doc(uid).collection('my_bills').doc(id).set(Map<String,dynamic>.from(b), SetOptions(merge: true));
      }
    } catch (e) { print("saveBills error: $e"); }
  }

  void saveUsers() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance(); prefs.setString('users_data_$uid', json.encode(allUsers));
      for (var u in allUsers) { await _firestore.collection('isps').doc(uid).collection('my_users').doc(u['phone'].toString()).set(Map<String,dynamic>.from(u), SetOptions(merge: true)); }
    } catch (e) { print("saveUsers error: $e"); }
  }

  void saveCollections() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    try {
      Map<String, dynamic> uniqueMap = {};
      for(var c in allCollections){
        String id = c['id']?.toString()?? "";
        if(id.isEmpty) continue;
        uniqueMap[id] = c;
      }
      allCollections = uniqueMap.values.toList();
      final prefs = await SharedPreferences.getInstance(); prefs.setString('collections_$uid', json.encode(allCollections));
      for (var c in allCollections) { String id = c['id']?.toString()?? DateTime.now().millisecondsSinceEpoch.toString(); await _firestore.collection('isps').doc(uid).collection('my_collections').doc(id).set(Map<String,dynamic>.from(c), SetOptions(merge: true)); }
    } catch (e) { print("saveCollections error: $e"); }
  }

  int daysLeft(dynamic expiryString, int? expiryMillis) {
    try {
      DateTime exp;
      if (expiryMillis!= null) { exp = DateTime.fromMillisecondsSinceEpoch(expiryMillis); }
      else if (expiryString!= null) { exp = DateTime.parse(expiryString.toString()); }
      else { return 999; }
      DateTime now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      DateTime expDate = DateTime(exp.year, exp.month, exp.day);
      return expDate.difference(now).inDays;
    } catch (e) { return 0; }
  }

  Future<void> checkAndGenerateAutoBills() async {
    final now = DateTime.now(); String currentMonthKey = "${now.year}-${now.month}"; bool added = false;
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if(uid==null) return;
    for (var u in allUsers) {
      int left = daysLeft(u['expiry'], u['expiryDate']);
      if (left < 0) {
        if (u['isActive']!= false) u['isActive'] = false;
        bool exists = allBills.any((b) => b['phone'].toString() == u['phone'].toString() && b['billMonth'] == currentMonthKey);
        if (!exists) {
          var newBill = {"name": u['name'], "phone": u['phone'].toString(), "amount": u['amount'], "package": u['package'], "isPaid": false, "date": now.toIso8601String(), "billMonth": currentMonthKey, "createdAt": now.millisecondsSinceEpoch, "autoGenerated": true};
          allBills.add(newBill);
          String id = "${newBill['phone']}_${newBill['billMonth']}_${newBill['createdAt']}";
          await _firestore.collection('isps').doc(uid).collection('my_bills').doc(id).set(newBill);
          added = true;
        }
      }
    }
    allBills.removeWhere((b) =>!allUsers.any((u) => u['phone'].toString() == b['phone'].toString()));
    if (added) { saveBills(); saveUsers(); if (mounted) setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) { return const Scaffold(body: Center(child: CircularProgressIndicator())); }
    final pages = [
      DashboardScreen(bills: allBills, collections: allCollections, users: allUsers),
      BillsScreen(bills: allBills, users: allUsers, onUpdate: () { saveBills(); setState(() {}); }, onUsersUpdate: () { saveUsers(); setState(() {}); }, onCollectionAdd: (Map<String, dynamic> col) { setState(() => allCollections.add(col)); saveCollections(); }),
      UsersScreen(users: allUsers, bills: allBills, collections: allCollections, onUsersUpdate: () { saveUsers(); checkAndGenerateAutoBills(); setState(() {}); }, onBillsUpdate: () { saveBills(); setState(() {}); }, onCollectionsUpdate: () { saveCollections(); setState(() {}); }),
      ReportsScreen(bills: allBills, collections: allCollections),
      SettingsScreen(),
    ];
    return Scaffold(backgroundColor: const Color(0xFF121212), appBar: AppBar(backgroundColor: const Color(0xFF121212), title: Text(titles[_index], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))), drawer: Drawer(backgroundColor: const Color(0xFF1E1E1E), child: Column(children: [ Container(width: double.infinity, padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF4A00E0)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.wifi, color: Color(0xFF7C4DFF), size: 36)), const SizedBox(height: 12), Text(bizName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)), Text(FirebaseAuth.instance.currentUser?.email?? bizPhone, style: const TextStyle(color: Colors.white70, fontSize: 11))])), const SizedBox(height: 10), _drawerItem(Icons.dashboard_rounded, "Dashboard", 0), _drawerItem(Icons.receipt_long_rounded, "Bills", 1), _drawerItem(Icons.people_rounded, "Users", 2), _drawerItem(Icons.bar_chart_rounded, "Reports", 3), _drawerItem(Icons.settings_rounded, "Settings", 4), const Spacer(), const Divider(color: Colors.white12), ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text("Logout", style: TextStyle(color: Colors.redAccent)), onTap: () async { bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Color(0xFF1E1E1E), title: Text("Logout?", style: TextStyle(color: Colors.white)), content: Text("Logout karna hai?", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: ()=> Navigator.pop(c,false), child: Text("Nahi")), TextButton(onPressed: ()=> Navigator.pop(c,true), child: Text("Haan", style: TextStyle(color: Colors.red)))]))?? false; if(!confirm) return; await FirebaseAuth.instance.signOut(); if(mounted) Navigator.pop(context); },), const SizedBox(height: 10), ]), ), body: pages[_index], bottomNavigationBar: BottomNavigationBar(backgroundColor: const Color(0xFF1E1E1E), selectedItemColor: const Color(0xFF7C4DFF), unselectedItemColor: Colors.white54, currentIndex: _index, onTap: (i) { setState(() => _index = i); if (i == 1 || i == 0) checkAndGenerateAutoBills(); }, type: BottomNavigationBarType.fixed, items: const [BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Bills"), BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"), BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"), BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings")]), );
  }
  Widget _drawerItem(IconData icon, String title, int index) { bool isSelected = _index == index; return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isSelected? const Color(0xFF7C4DFF).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Icon(icon, color: isSelected? const Color(0xFF7C4DFF) : Colors.white60), title: Text(title, style: GoogleFonts.poppins(color: isSelected? Colors.white : Colors.white70, fontSize: 14)), onTap: () { setState(() => _index = index); Navigator.pop(context); if (index == 1 || index == 0) checkAndGenerateAutoBills(); })); }
}