import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:router_os_client/router_os_client.dart';
import 'package:flutter/foundation.dart';

class MikrotikService {
  static Future<Map<String, String>> _getConfig() async {
    var p = await SharedPreferences.getInstance();
    return {
      'ip': (p.getString('mt_ip')?? '').trim(),
      'user': (p.getString('mt_user')?? 'admin').trim(),
      'pass': p.getString('mt_pass')?? '',
      'port': (p.getString('mt_port')?? '8728').trim(),
    };
  }

  static RouterOSClient _makeClient(Map<String, String> cfg) {
    int port = int.tryParse(cfg['port']?? '8728')?? 8728;
    return RouterOSClient(
      address: cfg['ip']!,
      user: cfg['user']!,
      password: cfg['pass']!,
      port: port,
      useSsl: port == 8729,
      timeout: Duration(seconds: 7),
    );
  }

  static Future<Map<String, dynamic>> testConnection() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP khali hai - Settings me IP dalo'};

    if (cfg['port'] == '80' || cfg['port'] == '443') {
      try {
        var url = Uri.parse("http://${cfg['ip']}:${cfg['port']}/rest/system/resource");
        var res = await http.get(url, headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${cfg['user']}:${cfg['pass']}'))}',
        }).timeout(Duration(seconds: 5));
        if (res.statusCode == 200) return {'ok': true, 'msg': 'Connected REST OK - Lekin Port 8728 zyada behtar hai'};
        return {'ok': false, 'msg': 'REST Fail ${res.statusCode}. Settings me Port 8728 likho'};
      } catch (e) {
        return {'ok': false, 'msg': 'REST Fail: $e - Port 8728 use karo'};
      }
    }

    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool ok = await client.login();
      if (!ok) {
        client.close();
        return {'ok': false, 'msg': 'Login fail - User/Pass ghalat'};
      }
      var data = await client.talk(['/system/resource/print']);
      client.close();
      String board = data.isNotEmpty? data[0]['board-name']?? 'Mikrotik' : 'Mikrotik';
      String version = data.isNotEmpty? data[0]['version']?? '' : '';
      return {'ok': true, 'msg': 'Connected! $board $version - Port ${cfg['port']} OK'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'API Fail: $e. Winbox > IP > Services me API ON karo'};
    }
  }

  static Future<Map<String, dynamic>> addPppUser({required String username, required String password, required String profile}) async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'MikroTik IP set nahi - Settings me jao'};
    if (username.trim().isEmpty || password.trim().isEmpty) return {'ok': false, 'msg': 'Username/Password khali hai'};

    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool loggedIn = await client.login();
      if(!loggedIn){
        client.close();
        return {'ok': false, 'msg': 'MikroTik Login Fail'};
      }

      var existing = await client.talk(['/ppp/secret/print', '?name=$username']);
      if (existing.isNotEmpty) {
        String id = existing[0]['.id']!;
        await client.talk([
          '/ppp/secret/set',
          '=.id=$id',
          '=password=$password',
          '=profile=$profile',
          '=service=pppoe',
          '=disabled=no'
        ]);
        client.close();
        return {'ok': true, 'msg': 'User Update ho gaya ($profile)'};
      }

      var profiles = await client.talk(['/ppp/profile/print', '?name=$profile']);
      if(profiles.isEmpty){
        var allProfiles = await client.talk(['/ppp/profile/print']);
        if(allProfiles.isNotEmpty && allProfiles.length == 1){
          profile = allProfiles[0]['name']?? 'default';
        }
      }

      await client.talk([
        '/ppp/secret/add',
        '=name=$username',
        '=password=$password',
        '=profile=$profile',
        '=service=pppoe',
        '=disabled=no',
        '=comment=Created by ISP PENNEL App'
      ]);
      client.close();
      return {'ok': true, 'msg': 'Mikrotik me user ban gaya ($profile)'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'Add fail: $e'};
    }
  }

  static Future<Map<String, dynamic>> createUser({required String username, required String password, required String profile}) async {
    return await addPppUser(username: username, password: password, profile: profile);
  }

  static Future<List<Map<String, dynamic>>> getOnlineUsersDetailed() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return [];
    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool ok = await client.login();
      if(!ok){ client.close(); return []; }
      var active = await client.talk(['/ppp/active/print']);
      var queues = await client.talk(['/queue/simple/print']);
      client.close();
      List<Map<String, dynamic>> result = [];
      for (var u in active) {
        var q = queues.firstWhere((qq) => qq['name'] == u['name'], orElse: () => <String, String>{});
        result.add({
          'username': u['name'],
          'ip': u['address'],
          'wan_ip': u['caller-id']?? '',
          'uptime': u['uptime'],
          'router': 'MikroTik-${cfg['ip']}',
          'bytes': q['bytes']?? '0/0',
          'speed': q['rate']?? '0/0',
        });
      }
      return result;
    } catch(e) {
      try{ client?.close(); }catch(_){}
      return [];
    }
  }

  static Future<Map<String, dynamic>> disableUser(String username) async => _setDisabled(username, true);
  static Future<Map<String, dynamic>> enableUser(String username) async => _setDisabled(username, false);

  static Future<Map<String, dynamic>> _setDisabled(String username, bool disable) async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP set nahi'};
    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool ok = await client.login();
      if(!ok){ client.close(); return {'ok': false, 'msg': 'Login fail'}; }
      var list = await client.talk(['/ppp/secret/print', '?name=$username']);
      if (list.isEmpty) {
        client.close();
        return {'ok': false, 'msg': 'User $username MikroTik me nahi mila'};
      }
      String id = list[0]['.id']!;
      await client.talk(['/ppp/secret/set', '=.id=$id', '=disabled=${disable? 'yes' : 'no'}']);
      if (disable) {
        var active = await client.talk(['/ppp/active/print', '?name=$username']);
        for (var a in active) {
          try{
            await client.talk(['/ppp/active/remove', '=.id=${a['.id']}']);
          }catch(_){}
        }
      }
      client.close();
      return {'ok': true, 'msg': disable? 'User Disable ho gaya' : 'User Enable ho gaya'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'Error: $e'};
    }
  }

  // === NEW: PERMANENT DELETE FROM MIKROTIK ===
  static Future<Map<String, dynamic>> deleteUser(String username) async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP set nahi - Settings check karo'};
    if (username.trim().isEmpty) return {'ok': false, 'msg': 'Username khali hai'};

    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool ok = await client.login();
      if(!ok){ client.close(); return {'ok': false, 'msg': 'MikroTik Login Fail'}; }

      // 1. Pehle active session remove karo (agar online hai)
      try {
        var active = await client.talk(['/ppp/active/print', '?name=$username']);
        for (var a in active) {
          try{
            await client.talk(['/ppp/active/remove', '=.id=${a['.id']}']);
          }catch(_){}
        }
      } catch (_) {}

      // 2. Ab secret se permanent delete karo
      var list = await client.talk(['/ppp/secret/print', '?name=$username']);
      if (list.isEmpty) {
        client.close();
        // User MikroTik pe nahi hai - isko success mano taake Firebase se delete ho sake
        return {'ok': true, 'msg': 'User MikroTik pe pehle se nahi tha'};
      }

      for (var item in list) {
        String id = item['.id']!;
        await client.talk(['/ppp/secret/remove', '=.id=$id']);
      }

      client.close();
      return {'ok': true, 'msg': 'MikroTik se permanent delete ho gaya'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'Delete Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkNat() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP set nahi'};
    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      await client.login();
      var natRules = await client.talk(['/ip/firewall/nat/print']);
      client.close();
      bool hasMasquerade = natRules.any((r) => r['action'] == 'masquerade');
      if(hasMasquerade){
        return {'ok': true, 'msg': 'NAT Masquerade laga hua hai'};
      }else{
        return {'ok': false, 'msg': 'NAT Masquerade nahi laga'};
      }
    } catch(e){
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'NAT check fail: $e'};
    }
  }

  static Future<List<String>> getExistingNames() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return [];
    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      bool ok = await client.login();
      if (!ok) {
        client.close();
        return [];
      }
      var list = await client.talk(['/ppp/secret/print']);
      client.close();
      return list.map((e) => e['name'].toString()).toList();
    } catch (e) {
      try { client?.close(); } catch (_) {}
      return [];
    }
  }

  static Future<void> createProfileIfNotExists(String profileName) async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return;
    RouterOSClient? client;
    try {
      client = _makeClient(cfg);
      await client.login();
      var profiles = await client.talk(['/ppp/profile/print', '?name=$profileName']);
      if (profiles.isEmpty) {
        await client.talk(['/ppp/profile/add', '=name=$profileName', '=local-address=10.0.0.1', '=remote-address=pppoe-pool']);
      }
      client.close();
    } catch (e) {
      try { client?.close(); } catch (_) {}
    }
  }

  static Future<Map<String, int>> restoreAllUsersToNewMikrotik(List<dynamic> firebaseUsers, {Function(String)? onLog}) async {
    int created = 0, skipped = 0, failed = 0;
    List<String> existing = await getExistingNames();
    onLog?.call("Mikrotik me ${existing.length} users pehle se hain...");

    for (var u in firebaseUsers) {
      String name = (u['pppoe_username']?? u['username']?? "").toString().trim();
      String pass = (u['pppoe_password']?? u['password']?? "1234").toString();
      String pkg = (u['package']?? "10 Mbps").toString();
      String profile = pkg.replaceAll(" Mbps", "M").replaceAll(" ", "");

      if (name.isEmpty) {
        failed++;
        continue;
      }

      if (existing.contains(name)) {
        skipped++;
        onLog?.call("SKIP: $name pehle se hai");
        continue;
      }

      await createProfileIfNotExists(profile);
      var res = await addPppUser(username: name, password: pass, profile: profile);
      if (res['ok'] == true) {
        created++;
        onLog?.call("OK: $name ban gaya");
      } else {
        failed++;
        onLog?.call("FAIL: $name - ${res['msg']}");
      }
    }
    return {"created": created, "skipped": skipped, "failed": failed};
  }
}