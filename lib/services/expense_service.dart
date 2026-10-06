import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class ExpenseService {
  static CollectionReference get expenseCol => FirebaseFirestore.instance.collection('isps').doc(FirebaseService.uid).collection('my_expenses');

  static Future<void> addExpense({required String title, required int amount, required String category}) async {
    String id = DateTime.now().millisecondsSinceEpoch.toString();
    await expenseCol.doc(id).set({
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'month': "${DateTime.now().year}-${DateTime.now().month}",
    });
  }

  static Future<void> deleteExpense(String id) async {
    await expenseCol.doc(id).delete();
  }
}