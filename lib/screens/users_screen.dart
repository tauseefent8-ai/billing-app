import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class UsersScreen extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> bills;
  final List<dynamic> collections;
  final VoidCallback onUsersUpdate;
  final VoidCallback onBillsUpdate;
  final VoidCallback onCollectionsUpdate;

  const UsersScreen({
    super.key,
    required this.users,
    required this.bills,
    required this.collections,
    required this.onUsersUpdate,
    required this.onBillsUpdate,
    required this.onCollectionsUpdate,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _firestore = FirebaseFirestore.instance;
  String search = "";
  XFile? _pickedCnicImage;
  String? _localImagePath;

  DateTime calculateExpiry(DateTime fromDate) {
    int year = fromDate.year;
    int month = fromDate.month + 1;
    if (month > 12) { month = 1; year++; }
    int day = fromDate.day;
    int lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) day = lastDay;
    return DateTime(year, month, day);
  }

  String formatDate(int? millis) {
    if (millis == null) return "-";
    DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${d.day}/${d.month}/${d.year}";
  }

  bool isExpired(Map<String, dynamic> user) {
    if (user['expiryDate'] == null) return false;
    try {
      DateTime expiry = DateTime.fromMillisecondsSinceEpoch(user['expiryDate']);
      return DateTime.now().isAfter(expiry);
    } catch (e) { return false; }
  }

  Future<String?> saveImageLocally(XFile image, String phone) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/cnic_images');
      if (!await folder.exists()) await folder.create(recursive: true);
      final newPath = '${folder.path}/$phone.jpg';
      await File(image.path).copy(newPath);
      return newPath;
    } catch (e) { return null; }
  }

  bool checkLocalImageExists(String? path) {
    if (kIsWeb) return false;
    if (path == null || path.isEmpty) return false;
    try { return File(path).existsSync(); } catch (e) { return false; }
  }

  void showUserDetails(Map<String, dynamic> user) {
    bool hasImage = checkLocalImageExists(user['cnicLocalPath']);
    bool expired = isExpired(user);
    double pendingDue = double.tryParse(user['pendingDue']?.toString()?? '0')?? 0;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            CircleAvatar(backgroundColor: expired? Colors.red : const Color(0xFF7C4DFF), child: Text(user['name'].isNotEmpty? user['name'][0].toUpperCase() : "U", style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 10),
            Expanded(child: Text(user['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(user['cnicLocalPath']), height: 160, width: double.infinity, fit: BoxFit.cover)),
              if (hasImage) const SizedBox(height: 15),
              _detailRow("Phone:", user['phone']),
              _detailRow("CNIC:", user['cnic']),
              _detailRow("Address:", user['address']),
              _detailRow("Package:", user['package']),
              _detailRow("Amount:", "${user['amount']} Rs"),
              const Divider(color: Colors.white24, height: 20),
              _detailRow("Active Date:", formatDate(user['createdAt'])),
              _detailRow("Expiry Date:", formatDate(user['expiryDate']), isExpiry: true, isExpired: expired),
              _detailRow("Status:", expired? "Expired" : "Active", isExpired: expired),

              if (pendingDue > 0) const Divider(color: Colors.white24, height: 20),
              if (pendingDue > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Pending Due:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Rs. ${pendingDue.toInt()}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

              const Divider(color: Colors.white24, height: 20),
              _detailRow("Username:", user['username']),
              _detailRow("Password:", user['password']),

              if (pendingDue > 0) const SizedBox(height: 15),
              if (pendingDue > 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payments, size: 18),
                    label: Text("Collect Pending Rs. ${pendingDue.toInt()}"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      try {
                        String? uid = FirebaseAuth.instance.currentUser?.uid;
                        String newId = DateTime.now().millisecondsSinceEpoch.toString();

                        Map<String,dynamic> colData = {
                          "name": user['name'],
                          "phone": user['phone'].toString(),
                          "amount": pendingDue,
                          "package": user['package'],
                          "date": DateTime.now().toIso8601String(),
                          "billMonth": "${DateTime.now().year}-${DateTime.now().month}",
                          "type": "pending_due_clear",
                          "id": newId
                        };

                        setState(() {
                          user['pendingDue'] = 0;
                          int idx = widget.users.indexWhere((u) => u['phone'].toString() == user['phone'].toString());
                          if (idx!= -1) widget.users[idx]['pendingDue'] = 0;
                          widget.collections.add(colData);
                        });

                        if (uid!= null) {
                          await _firestore.collection('isps').doc(uid).collection('my_users').doc(user['phone'].toString()).update({'pendingDue': 0});
                          await _firestore.collection('isps').doc(uid).collection('my_collections').doc(newId).set(colData);
                        }

                        widget.onUsersUpdate();
                        widget.onCollectionsUpdate();
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pending Rs. ${pendingDue.toInt()} Cleared"), backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
            onPressed: () {
              Navigator.pop(c);
              showAddUserDialog(editUser: Map<String, dynamic>.from(user), editIndex: widget.users.indexWhere((u) => u['phone'].toString() == user['phone'].toString()));
            },
            child: const Text("Edit"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value, {bool isExpiry = false, bool isExpired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value?? "-", style: TextStyle(color: isExpiry && isExpired? Colors.redAccent : isExpiry? Colors.greenAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: Text("Delete?", style: GoogleFonts.poppins(color: Colors.white)), content: Text("Do you want to delete ${user['name']}?", style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes", style: TextStyle(color: Colors.red)))]))?? false;
    if (!confirm) return;
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      await _firestore.collection('isps').doc(uid).collection('my_users').doc(user['phone'].toString().trim()).delete();
      await _firestore.collection('app_logins').doc(user['username'].toString().trim()).delete();

      var billsSnap = await _firestore.collection('isps').doc(uid).collection('my_bills').where('phone', isEqualTo: user['phone'].toString()).get();
      for(var doc in billsSnap.docs){
        await doc.reference.delete();
      }

      if (!kIsWeb && user['cnicLocalPath']!= null) {
        try { final file = File(user['cnicLocalPath']); if (await file.exists()) await file.delete(); } catch (e) {}
      }
      setState(() {
        widget.users.removeWhere((u) => u['phone'].toString() == user['phone'].toString());
        widget.bills.removeWhere((b) => b['phone'].toString() == user['phone'].toString());
      });
      widget.onUsersUpdate();
      widget.onBillsUpdate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Error: $e")));
    }
  }

  void showAddUserDialog({Map<String, dynamic>? editUser, int? editIndex}) {
    final nameCtrl = TextEditingController(text: editUser?['name']?? "");
    final phoneCtrl = TextEditingController(text: editUser?['phone']?? "");
    final cnicCtrl = TextEditingController(text: editUser?['cnic']?? "");
    final addressCtrl = TextEditingController(text: editUser?['address']?? "");
    final packageCtrl = TextEditingController(text: editUser?['package']?? "10 Mbps");
    final amountCtrl = TextEditingController(text: editUser?['amount']?.toString()?? "1000");
    final usernameCtrl = TextEditingController(text: editUser?['username']?? "");
    final passCtrl = TextEditingController(text: editUser?['password']?? "1234");
    DateTime selectedExpiry = editUser?['expiryDate']!= null? DateTime.fromMillisecondsSinceEpoch(editUser!['expiryDate']) : calculateExpiry(DateTime.now());
    _pickedCnicImage = null;
    _localImagePath = editUser?['cnicLocalPath'];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(editUser == null? "Add New Customer" : "Edit Customer", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _field(nameCtrl, "Name", Icons.person),
                _field(phoneCtrl, "Phone", Icons.phone, isNumber: true),
                _field(cnicCtrl, "CNIC Number", Icons.badge, isNumber: true),
                _field(addressCtrl, "Address", Icons.home),
                _field(packageCtrl, "Package", Icons.wifi),
                _field(amountCtrl, "Amount", Icons.money, isNumber: true),
                _field(usernameCtrl, "Username", Icons.account_circle),
                _field(passCtrl, "Password", Icons.lock, isPass: true),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: selectedExpiry, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!));
                    if (picked!= null) setDialogState(() => selectedExpiry = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [const Icon(Icons.calendar_today, size: 18, color: Colors.white54), const SizedBox(width: 10), Text("Expiry: ${selectedExpiry.day}/${selectedExpiry.month}/${selectedExpiry.year}", style: const TextStyle(color: Colors.white, fontSize: 13)), const Spacer(), const Icon(Icons.edit_calendar, size: 16, color: Colors.white54)]),
                  ),
                ),
                const SizedBox(height: 12),
                if (!kIsWeb)
                  InkWell(
                    onTap: () async {
                      try {
                        final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (img!= null) setDialogState(() => _pickedCnicImage = img);
                      } catch (e) {}
                    },
                    child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)), child: _pickedCnicImage!= null? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_pickedCnicImage!.path), fit: BoxFit.cover)) : checkLocalImageExists(_localImagePath)? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_localImagePath!), fit: BoxFit.cover)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.white54), Text("CNIC Image (Optional)", style: TextStyle(color: Colors.white54, fontSize: 11))])),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
              onPressed: isSaving? null : () async {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name & Phone required")));
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  String? uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) throw "Not Logged In";

                  String? finalPath = _localImagePath;
                  if (!kIsWeb && _pickedCnicImage!= null) {
                    finalPath = await saveImageLocally(_pickedCnicImage!, phoneCtrl.text.trim());
                  }

                  Map<String, dynamic> userData = {
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'cnic': cnicCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'package': packageCtrl.text.trim(),
                    'amount': int.tryParse(amountCtrl.text.trim())?? 1000,
                    'username': usernameCtrl.text.trim().isEmpty? phoneCtrl.text.trim() : usernameCtrl.text.trim(),
                    'password': passCtrl.text.trim().isEmpty? "1234" : passCtrl.text.trim(),
                    'cnicLocalPath': finalPath?? "",
                    'cnicImageUrl': "",
                    'isActive': true,
                    'createdAt': editUser?['createdAt']?? DateTime.now().millisecondsSinceEpoch,
                    'expiryDate': selectedExpiry.millisecondsSinceEpoch,
                    'expiry': "${selectedExpiry.year}-${selectedExpiry.month.toString().padLeft(2,'0')}-${selectedExpiry.day.toString().padLeft(2,'0')}",
                    'pendingDue': editUser?['pendingDue']?? 0,
                  };

                  await _firestore.collection('isps').doc(uid).collection('my_users').doc(phoneCtrl.text.trim()).set(userData, SetOptions(merge: true));
                  await _firestore.collection('app_logins').doc(userData['username'].toString().trim()).set({
                    'username': userData['username'],
                    'password': userData['password'],
                    'phone': userData['phone'],
                    'isp_id': uid,
                    'name': userData['name'],
                  }, SetOptions(merge: true));

                  if (editIndex!= null) {
                    setState(() => widget.users[editIndex] = userData);
                  } else {
                    setState(() {
                      widget.users.removeWhere((u) => u['phone'].toString() == userData['phone'].toString());
                      widget.users.add(userData);
                    });
                  }
                  widget.onUsersUpdate();
                  if (mounted) Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully"), backgroundColor: Colors.green));
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                }
              },
              child: isSaving? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(editUser == null? "Save" : "Update"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, bool isPass = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: ctrl, obscureText: isPass, keyboardType: isNumber? TextInputType.number : TextInputType.text, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: Colors.white54), filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))));
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filtered = widget.users.where((u) => u['name'].toString().toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF7C4DFF), onPressed: () => showAddUserDialog(), child: const Icon(Icons.add)),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Search customer...", prefixIcon: const Icon(Icons.search, color: Colors.white54), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                var u = filtered[i];
                bool hasLocalImage = checkLocalImageExists(u['cnicLocalPath']);
                bool expired = isExpired(u);
                double pending = double.tryParse(u['pendingDue']?.toString()?? '0')?? 0;
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    onTap: () => showUserDetails(Map<String, dynamic>.from(u)),
                    leading: hasLocalImage? CircleAvatar(backgroundImage: FileImage(File(u['cnicLocalPath']))) : CircleAvatar(backgroundColor: expired? Colors.red : pending > 0? Colors.orange : null, child: Text(u['name'].isNotEmpty? u['name'][0] : "U")),
                    title: Row(children: [
                      Expanded(child: Text(u['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14))),
                      if (expired) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("Expired", style: TextStyle(color: Colors.white, fontSize: 9))),
                      if (pending > 0 &&!expired) Container(margin: const EdgeInsets.only(left: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: Text("Due ${pending.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 9))),
                    ]),
                    subtitle: Text("${u['phone']} | Exp: ${formatDate(u['expiryDate'])}${pending > 0? " | Due: ${pending.toInt()}" : ""}", style: TextStyle(color: expired? Colors.redAccent : pending > 0? Colors.orangeAccent : Colors.white54, fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => showAddUserDialog(editUser: Map<String, dynamic>.from(u), editIndex: widget.users.indexOf(u))), IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => deleteUser(Map<String, dynamic>.from(u)))]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}