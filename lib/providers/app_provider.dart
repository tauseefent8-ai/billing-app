import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/offline_service.dart';

class AppProvider extends ChangeNotifier {
  List<dynamic> users = [];
  List<dynamic> bills = [];
  List<dynamic> collections = [];
  bool isLoading = true;
  int currentPage = 0;
  int pageSize = 50;

  Future<void> initAll() async {
    isLoading = true;
    notifyListeners();
    try {
      // Pehle offline se load
      users = await OfflineService.getUsers();
      bills = await OfflineService.getBills();
      collections = await OfflineService.getCollections();
      isLoading = false;
      notifyListeners();

      // Phir Firebase se fresh
      var uSnap = await FirebaseService.usersCol.get();
      var bSnap = await FirebaseService.billsCol.get();
      var cSnap = await FirebaseService.collectionsCol.get();

      users = uSnap.docs.map((d)=> d.data()).toList();
      bills = bSnap.docs.map((d)=> d.data()).toList();
      collections = cSnap.docs.map((d)=> d.data()).toList();

      await OfflineService.saveAll(users, bills, collections);
    } catch(e){
      debugPrint("Provider Load Error $e");
    }
    isLoading = false;
    notifyListeners();
  }

  List<dynamic> get paginatedUsers {
    int start = currentPage * pageSize;
    int end = start + pageSize;
    if(start >= users.length) return [];
    if(end > users.length) end = users.length;
    return users.sublist(start, end);
  }

  int get totalPages => (users.length / pageSize).ceil();

  void nextPage(){
    if(currentPage < totalPages -1){ currentPage++; notifyListeners(); }
  }
  void prevPage(){
    if(currentPage >0){ currentPage--; notifyListeners(); }
  }

  void addUserLocal(Map<String,dynamic> u){
    users.add(u);
    OfflineService.saveAll(users, bills, collections);
    notifyListeners();
  }
  void removeUserLocal(String phone){
    users.removeWhere((x)=> x['phone'].toString()==phone);
    OfflineService.saveAll(users, bills, collections);
    notifyListeners();
  }
}