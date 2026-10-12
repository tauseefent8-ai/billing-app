import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static const String _fallbackId = "kPaksjGOLLROhyCHmDGgSIGizCf1";

  static String get uid {
    String authUid = FirebaseAuth.instance.currentUser?.uid?? "";
    if (authUid.isNotEmpty) return authUid;
    debugPrint("⚠️ Auth NULL hai, fallback ID use ho raha: $_fallbackId");
    return _fallbackId;
  }

  static bool get isUidValid => uid.isNotEmpty;

  static DocumentReference get ispDoc {
    return _firestore.collection('isps').doc(uid);
  }

  static CollectionReference get usersCol {
    return ispDoc.collection('my_users');
  }
  static CollectionReference get billsCol {
    return ispDoc.collection('my_bills');
  }
  static CollectionReference get collectionsCol {
    return ispDoc.collection('my_collections');
  }
  static CollectionReference get expensesCol {
    return ispDoc.collection('my_expenses');
  }

  static Future<void> ensureIspDoc() async {
    try {
      debugPrint("=== ENSURE ISP DOC: isps/$uid ===");
      await ispDoc.set({
        'biz_name': 'MK-Fiber',
        'companyName': 'MK-Fiber',
        'email': FirebaseAuth.instance.currentUser?.email?? 'et1styear786@gmail.com',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'verified': true,
      }, SetOptions(merge: true));
      debugPrint("✅ ISP DOC ENSURED");
    } catch (e) {
      debugPrint("❌ ensureIspDoc error: $e");
      rethrow;
    }
  }

  static Future<void> updateUserDue(String phone, double newDue) async {
    if (phone.trim().isEmpty) return;
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      String docId = cleanPhone.isNotEmpty? cleanPhone : phone.trim();
      await usersCol.doc(docId).set({'pendingDue': newDue}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Due error: $e");
    }
  }

  static int parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    String s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s)?? 0;
  }

  static String genBillId(String phone, String month) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return "${cleanPhone}_${month}_${DateTime.now().millisecondsSinceEpoch}";
  }

  static Future<void> batchWriteBills(List<Map<String, dynamic>> bills) async {
    if (bills.isEmpty) return;
    WriteBatch batch = _firestore.batch();
    for (var bill in bills) {
      if (bill['id'] == null) continue;
      batch.set(billsCol.doc(bill['id'].toString()), bill, SetOptions(merge: true));
    }
    await batch.commit();
  }
}