import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/offline_service.dart';
import 'providers/app_provider.dart';
import 'services/export_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/login_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/customer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineService.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider()..initAll())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ISP PENNEL',
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF121212), textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // FIXED PART 2: Pehle 1000 queries lagti thi, ab sirf 2 queries lagegi - Collection Group Query
  Future<bool> isCustomer(String email, String phone) async {
    try{
      if(email.isEmpty && phone.isEmpty) return false;
      
      // Direct collectionGroup search - fast & cheap
      if(email.isNotEmpty){
        var snap = await FirebaseFirestore.instance.collectionGroup('my_users').where('email', isEqualTo: email).limit(1).get();
        if(snap.docs.isNotEmpty) return true;
      }
      if(phone.isNotEmpty){
        // Phone ko clean karke search karo
        String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        var snap2 = await FirebaseFirestore.instance.collectionGroup('my_users').where('phone', isEqualTo: phone).limit(1).get();
        if(snap2.docs.isNotEmpty) return true;
        // Clean phone se bhi check
        if(cleanPhone != phone){
          var snap3 = await FirebaseFirestore.instance.collectionGroup('my_users').where('phone', isEqualTo: cleanPhone).limit(1).get();
          if(snap3.docs.isNotEmpty) return true;
        }
      }
    }catch(e){
      debugPrint("isCustomer error: $e - Firestore Index chahiye hoga collectionGroup ke liye");
      // Fallback purana tareeqa agar index na bana ho to
      try{
        var isps = await FirebaseFirestore.instance.collection('isps').limit(20).get();
        for(var ispDoc in isps.docs){
          var snap = await ispDoc.reference.collection('my_users').where('email', isEqualTo: email).limit(1).get();
          if(snap.docs.isNotEmpty) return true;
        }
      }catch(e2){}
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snap){
      if(snap.connectionState==ConnectionState.waiting){ return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))); }
      if(snap.hasData){
        String email = snap.data?.email?? "";
        String phone = snap.data?.phoneNumber?? "";
        return FutureBuilder<bool>(future: isCustomer(email, phone), builder: (context, roleSnap){
          if(roleSnap.connectionState==ConnectionState.waiting){ return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))); }
          if(roleSnap.data==true){ return const CustomerDashboard(); }
          return const MainScreen();
        });
      }
      return const LoginScreen();
    });
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int selectedIndex = 0;
  String bizName = "ISP PENNEL";
  String? profilePicPath;
  bool picExists = false;
  final _firestore = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid?? "";
  late AnimationController _controller; late Animation<double> _fadeAnim;

  @override
  void initState(){ super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250)); _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut); _controller.forward(); _loadBizInfo(); }
  @override
  void dispose(){ _controller.dispose(); super.dispose(); }

  _loadBizInfo() async {
    final p = await SharedPreferences.getInstance();
    String? savedPic = p.getString('profile_pic_$uid');
    String savedName = p.getString('biz_name_$uid') ?? p.getString('biz_name') ?? "ISP PENNEL";
    bool exists = false;
    if(savedPic != null && !kIsWeb){
      try{ exists = File(savedPic).existsSync(); }catch(e){ exists = false; }
    }
    try{ if(uid.isNotEmpty){ var doc = await _firestore.collection('isps').doc(uid).get(); if(doc.exists){ String fbName = doc.data()?['biz_name']?? doc.data()?['companyName']?? ""; if(fbName.isNotEmpty) savedName = fbName; } } }catch(e){}
    if(mounted) setState((){ bizName = savedName.isEmpty? "ISP PENNEL" : savedName; profilePicPath = savedPic; picExists = exists; });
  }

  Future<void> pickProfilePic() async {
    final picker = ImagePicker();
    showModalBottomSheet(context: context, backgroundColor: Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c)=> Container(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text("Profile Photo Select Karo", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton.icon(icon: Icon(Icons.camera_alt), label: Text("Camera"), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async { Navigator.pop(c); XFile? file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70); if(file!=null) await _savePic(file); }),
        ElevatedButton.icon(icon: Icon(Icons.photo), label: Text("Gallery"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () async { Navigator.pop(c); XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); if(file!=null) await _savePic(file); }),
      ])
    ])));
  }
  Future<void> _savePic(XFile file) async {
    try{ final p = await SharedPreferences.getInstance(); final dir = await getApplicationDocumentsDirectory(); final newFile = File('${dir.path}/profile_$uid.jpg'); await newFile.writeAsBytes(await file.readAsBytes()); await p.setString('profile_pic_$uid', newFile.path); if(mounted) setState((){ profilePicPath = newFile.path; picExists = true; }); if(mounted){ ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Profile photo save ho gayi"), backgroundColor: Colors.green, duration: Duration(seconds: 5))); } }catch(e){ if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 5))); } }
  }
  void _editCompanyName(){
    TextEditingController c = TextEditingController(text: bizName);
    showDialog(context: context, builder: (ctx)=> AlertDialog(backgroundColor: Color(0xFF1E1E1E), title: Text("Company Name Edit Karo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)), content: TextField(controller: c, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Company Name", hintText: "ISP PENNEL", labelStyle: TextStyle(color: Colors.white54))), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async { final p = await SharedPreferences.getInstance(); String newName = c.text.trim().isEmpty? "ISP PENNEL" : c.text.trim(); await p.setString('biz_name_$uid', newName); await p.setString('biz_name', newName); if(uid.isNotEmpty){ await _firestore.collection('isps').doc(uid).set({'biz_name': newName, 'companyName': newName}, SetOptions(merge:true)); } if(mounted) setState(()=> bizName = newName); if(mounted) Navigator.pop(ctx); if(mounted){ ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Company name $newName save ho gaya"), backgroundColor: Colors.green, duration: Duration(seconds: 5))); } }, child: Text("Save"))],));
  }

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<AppProvider>(context);
    List<Widget> screens = [
      DashboardScreen(bills: provider.bills, collections: provider.collections, users: provider.users),
      BillsScreen(bills: provider.bills, users: provider.users, collections: provider.collections, onUpdate: (){ setState((){}); }, onUsersUpdate: (){ setState((){}); }, onCollectionAdd: (col){ provider.collections.add(col); }, onCollectionRemove: (id){ provider.collections.removeWhere((x)=> x['id'].toString()==id || x['phone'].toString()==id); }),
      UsersScreen(users: provider.users, bills: provider.bills, collections: provider.collections, onUsersUpdate: (){ setState((){}); }, onBillsUpdate: (){ setState((){}); }, onCollectionsUpdate: (){ setState((){}); }),
      ReportsScreen(bills: provider.bills, collections: provider.collections, users: provider.users),
      const ExpenseScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: Text(bizName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), actions: [
        IconButton(icon: Icon(Icons.download, color: Colors.white70), tooltip: "Export Excel", onPressed: ()=> ExportService.exportToExcel(context, provider.users, provider.bills, provider.collections)),
        IconButton(icon: Icon(Icons.refresh, color: Colors.white70), onPressed: ()=> provider.initAll()),
      ]),
      drawer: Drawer(backgroundColor: const Color(0xFF1E1E1E), child: ListView(padding: EdgeInsets.zero, children: [
        UserAccountsDrawerHeader(decoration: BoxDecoration(color: Color(0xFF7C4DFF)), currentAccountPicture: GestureDetector(onTap: pickProfilePic, child: CircleAvatar(backgroundColor: Colors.white, backgroundImage: profilePicPath!=null && picExists && !kIsWeb ? FileImage(File(profilePicPath!)) : null, child: profilePicPath==null || !picExists ? Icon(Icons.person, size: 40, color: Color(0xFF7C4DFF)) : null)), accountName: GestureDetector(onTap: _editCompanyName, child: Row(children: [Flexible(child: Text(bizName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)), SizedBox(width: 6), Icon(Icons.edit, size: 14, color: Colors.white70)])), accountEmail: Text(FirebaseAuth.instance.currentUser?.email?? "No Email", style: GoogleFonts.poppins(fontSize: 12))),
        ListTile(leading: Icon(Icons.dashboard, color: Colors.white70), title: Text("Dashboard", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=0); Navigator.pop(context); }),
        ListTile(leading: Icon(Icons.receipt, color: Colors.white70), title: Text("Bills", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=1); Navigator.pop(context); }),
        ListTile(leading: Icon(Icons.people, color: Colors.white70), title: Text("Customers", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=2); Navigator.pop(context); }),
        ListTile(leading: Icon(Icons.bar_chart, color: Colors.white70), title: Text("Reports + Profit", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=3); Navigator.pop(context); }),
        ListTile(leading: Icon(Icons.money_off, color: Colors.white70), title: Text("Kharcha - Expense", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=4); Navigator.pop(context); }),
        ListTile(leading: Icon(Icons.settings, color: Colors.white70), title: Text("Settings - ISP PENNEL", style: GoogleFonts.poppins(color: Colors.white)), onTap: (){ setState(()=> selectedIndex=5); Navigator.pop(context); }),
        Divider(color: Colors.white12),
        ListTile(leading: Icon(Icons.camera_alt, color: Colors.white70), title: Text("Profile Photo Badlo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), onTap: (){ Navigator.pop(context); pickProfilePic(); }),
        ListTile(leading: Icon(Icons.edit, color: Colors.white70), title: Text("Company Name Edit Karo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), onTap: (){ Navigator.pop(context); _editCompanyName(); }),
        ListTile(leading: Icon(Icons.file_download, color: Colors.greenAccent), title: Text("Excel Export Karo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), onTap: (){ Navigator.pop(context); ExportService.exportToExcel(context, provider.users, provider.bills, provider.collections); }),
        SizedBox(height: 20),
        Padding(padding: EdgeInsets.all(12), child: Text("ISP PENNEL - Offline + Expense + Customer Login", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10))),
      ])),
      body: provider.isLoading? Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))) : FadeTransition(opacity: _fadeAnim, child: screens[selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(backgroundColor: const Color(0xFF1E1E1E), selectedItemColor: const Color(0xFF7C4DFF), unselectedItemColor: Colors.white54, currentIndex: selectedIndex, type: BottomNavigationBarType.fixed, onTap: (i){ setState(()=> selectedIndex=i); _controller.forward(from: 0); }, items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Bills"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"),
        BottomNavigationBarItem(icon: Icon(Icons.money_off), label: "Kharcha"),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
      ]),
    );
  }
}