import 'package:hive_flutter/hive_flutter.dart';

class OfflineService {
  static Box? box;

  static Future<void> init() async {
    await Hive.initFlutter();
    box = await Hive.openBox('isp_pennel_box');
  }

  static Future<void> saveAll(List users, List bills, List collections) async {
    await box?.put('users', users);
    await box?.put('bills', bills);
    await box?.put('collections', collections);
  }

  static Future<List> getUsers() async {
    return List.from(box?.get('users')?? []);
  }
  static Future<List> getBills() async {
    return List.from(box?.get('bills')?? []);
  }
  static Future<List> getCollections() async {
    return List.from(box?.get('collections')?? []);
  }
}