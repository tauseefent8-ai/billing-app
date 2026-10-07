import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static Box? box;

  static Future<void> init() async {
    await Hive.initFlutter();
    box = await Hive.openBox('isp_pennel_box');
  }

  static Future<void> saveAll(List users, List bills, List collections) async {
    try{
      await box?.put('users', users);
      await box?.put('bills', bills);
      await box?.put('collections', collections);
      await box?.put('last_save', DateTime.now().millisecondsSinceEpoch);
    }catch(e){
      debugPrint("Offline save error: $e");
    }
  }

  static Future<List> getUsers() async {
    try{
      return List.from(box?.get('users')?? []);
    }catch(e){
      return [];
    }
  }

  static Future<List> getBills() async {
    try{
      return List.from(box?.get('bills')?? []);
    }catch(e){
      return [];
    }
  }

  static Future<List> getCollections() async {
    try{
      return List.from(box?.get('collections')?? []);
    }catch(e){
      return [];
    }
  }

  // FIXED: Logout pe data leak na ho, is liye clear function
  static Future<void> clearAll() async {
    try{
      await box?.clear();
      debugPrint("Offline box cleared - logout safe");
    }catch(e){
      debugPrint("Clear error: $e");
    }
  }

  static Future<void> clearForUid(String uid) async {
    // Agar multi-user support chahiye to uid wise clear
    await clearAll();
  }
}