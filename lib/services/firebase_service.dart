import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser?.uid?? "";

  static CollectionReference get usersCol => _firestore.collection('isps').doc(uid).collection('my_users');
  static CollectionReference get billsCol => _firestore.collection('isps').doc(uid).collection('my_bills');
  static CollectionReference get collectionsCol => _firestore.collection('isps').doc(uid).collection('my_collections');

  // PendingDue ek jagah se update - bug khatam
  static Future<void> updateUserDue(String phone, double newDue) async {
    await usersCol.doc(phone).set({'pendingDue': newDue}, SetOptions(merge: true));
  }

  static int parseAmount(dynamic v){
    if(v==null) return 0;
    if(v is int) return v;
    if(v is num) return v.toInt();
    return int.tryParse(v.toString())?? 0;
  }

  // UUID generate - phone duplicate masla khatam
  static String genBillId(String phone, String month) {
    return "${phone}_${month}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}";
  }
}