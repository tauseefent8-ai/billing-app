import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser?.uid?? "";

  static bool get isUidValid => uid.isNotEmpty;

  static CollectionReference get usersCol {
    if(!isUidValid) throw Exception("User not logged in - uid empty");
    return _firestore.collection('isps').doc(uid).collection('my_users');
  }
  static CollectionReference get billsCol {
    if(!isUidValid) throw Exception("User not logged in - uid empty");
    return _firestore.collection('isps').doc(uid).collection('my_bills');
  }
  static CollectionReference get collectionsCol {
    if(!isUidValid) throw Exception("User not logged in - uid empty");
    return _firestore.collection('isps').doc(uid).collection('my_collections');
  }

  static Future<void> updateUserDue(String phone, double newDue) async {
    if(!isUidValid) return;
    if(phone.trim().isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String docId = cleanPhone.isNotEmpty ? cleanPhone : phone.trim();
    try{
      await usersCol.doc(docId).set({'pendingDue': newDue}, SetOptions(merge: true));
    }catch(e){
      debugPrint("updateUserDue error: $e");
    }
  }

  static int parseAmount(dynamic v){
    if(v==null) return 0;
    if(v is int) return v;
    if(v is double) return v.toInt();
    if(v is num) return v.toInt();
    String s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(s) ?? int.tryParse(v.toString()) ?? 0;
  }

  static String genBillId(String phone, String month) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // UUID jaisa unique ID - timestamp + random
    return "${cleanPhone}_${month}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}";
  }

  // Batch write helper for bills
  static Future<void> batchWriteBills(List<Map<String,dynamic>> bills) async {
    if(!isUidValid) return;
    if(bills.isEmpty) return;
    WriteBatch batch = _firestore.batch();
    for(var bill in bills){
      if(bill['id'] == null) continue;
      batch.set(billsCol.doc(bill['id'].toString()), bill, SetOptions(merge: true));
    }
    await batch.commit();
  }
}