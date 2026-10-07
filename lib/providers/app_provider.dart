import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/offline_service.dart';

class AppProvider extends ChangeNotifier {
  List<dynamic> users = [];
  List<dynamic> bills = [];
  List<dynamic> collections = [];
  bool isLoading = true;
  int currentPage = 0;

  String get uid => FirebaseAuth.instance.currentUser?.uid?? "";

  Future<void> initAll() async {
    isLoading = true;
    notifyListeners();

    try{
      // Pehle offline data dikhao - tez loading
      users = await OfflineService.getUsers();
      bills = await OfflineService.getBills();
      collections = await OfflineService.getCollections();
      if(users.isNotEmpty || bills.isNotEmpty){
        isLoading = false;
        notifyListeners();
      }

      // Phir Firebase se fresh data lao agar login hai
      if(uid.isEmpty){
        isLoading = false;
        notifyListeners();
        return;
      }

      // Parallel fetch - fast
      var results = await Future.wait([
        FirebaseService.usersCol.get(),
        FirebaseService.billsCol.orderBy('createdAt', descending: true).limit(500).get(),
        FirebaseService.collectionsCol.orderBy('date', descending: true).limit(500).get(),
      ]);

      var usersSnap = results[0] as QuerySnapshot;
      var billsSnap = results[1] as QuerySnapshot;
      var collectionsSnap = results[2] as QuerySnapshot;

      users = usersSnap.docs.map((d) => d.data()).toList();
      bills = billsSnap.docs.map((d) => d.data()).toList();
      collections = collectionsSnap.docs.map((d) => d.data()).toList();

      // FIXED: Await lagaya, race condition khatam
      await OfflineService.saveAll(users, bills, collections);

    }catch(e){
      debugPrint("initAll error: $e");
      // Agar offline data hai to usi pe chalo, error na dikhao
      if(users.isEmpty){
        try{
          users = await OfflineService.getUsers();
          bills = await OfflineService.getBills();
          collections = await OfflineService.getCollections();
        }catch(_){}
      }
    }

    isLoading = false;
    notifyListeners();
  }

  // FIXED: Local add with clean phone
  void addUserLocal(Map<String,dynamic> userData){
    try{
      String phone = userData['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if(phone.isNotEmpty){
        userData['phone'] = phone;
      }
      // Duplicate check
      users.removeWhere((u) => u['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '') == phone);
      users.insert(0, userData);
      // FIXED: Await nahi kar sakte kyunki sync hai, lekin background me save karo
      OfflineService.saveAll(users, bills, collections);
      notifyListeners();
    }catch(e){
      debugPrint("addUserLocal error: $e");
    }
  }

  Future<void> removeUserLocal(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    users.removeWhere((u) => u['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '') == cleanPhone || u['phone'].toString() == phone);
    await OfflineService.saveAll(users, bills, collections);
    notifyListeners();
  }

  void goToFirstPage(){
    currentPage = 0;
    notifyListeners();
  }

  Future<void> clearAllOnLogout() async {
    users = [];
    bills = [];
    collections = [];
    currentPage = 0;
    await OfflineService.clearAll();
    notifyListeners();
  }

  // Safe add for collections/bills
  Future<void> addCollectionLocal(Map<String,dynamic> col) async {
    collections.insert(0, col);
    await OfflineService.saveAll(users, bills, collections);
    notifyListeners();
  }

  Future<void> addBillLocal(Map<String,dynamic> bill) async {
    bills.insert(0, bill);
    await OfflineService.saveAll(users, bills, collections);
    notifyListeners();
  }
}