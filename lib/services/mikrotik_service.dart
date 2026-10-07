import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:router_os_client/router_os_client.dart';
import 'package:flutter/foundation.dart';

class MikrotikService {
  static Future<Map<String, String>> _getConfig() async {
    var p = await SharedPreferences.getInstance();
    return {
      'ip': (p.getString('mt_ip') ?? '').trim(),
      'user': (p.getString('mt_user') ?? 'admin').trim(),
      'pass': p.getString('mt_pass') ?? '',
      'port': (p.getString('mt_port') ?? '8728').trim(), // FIXED: Default ab 8728 hai, 80 nahi
    };
  }

  static RouterOSClient _makeClient(Map<String, String> cfg) {
    int port = int.tryParse(cfg['port'] ?? '8728') ?? 8728;
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
    
    // FIXED: Agar port 80/443 hai to user ko warning do ki 8728 use kare
    if (cfg['port'] == '80' || cfg['port'] == '443') {
      try {
        var url = Uri.parse("http://${cfg['ip']}:${cfg['port']}/rest/system/resource");
        var res = await http.get(url, headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${cfg['user']}:${cfg['pass']}'))}',
        }).timeout(Duration(seconds: 5));
        if (res.statusCode == 200) return {'ok': true, 'msg': 'Connected REST OK - Lekin Port 8728 zyada behtar hai'};
        return {'ok': false, 'msg': 'REST Fail ${res.statusCode}. Settings me Port 8728 likho aur IP>Services me API Enable karo'};
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
        return {'ok': false, 'msg': 'Login fail - User/Pass ghalat ya IP ghalat'};
      }
      var data = await client.talk(['/system/resource/print']);
      client.close();
      String board = data.isNotEmpty ? data[0]['board-name'] ?? 'Mikrotik' : 'Mikrotik';
      String version = data.isNotEmpty ? data[0]['version'] ?? '' : '';
      return {'ok': true, 'msg': 'Connected! $board $version - Port ${cfg['port']} OK'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'API Fail: $e. Winbox > IP > Services me API ON karo Port ${cfg['port']} pe'};
    }
  }

  // FINAL FIX - DIALUP KE LIYE 100% WORKING - Client close fix
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
        return {'ok': false, 'msg': 'MikroTik Login Fail - User/Pass check karo'};
      }

      // Check if user already exists - agar hai to update karo
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
        return {'ok': true, 'msg': 'User Update ho gaya MikroTik me ($profile) - Dialup Ready'};
      }

      // Check profile exists
      var profiles = await client.talk(['/ppp/profile/print', '?name=$profile']);
      if(profiles.isEmpty){
        // Agar profile nahi mila to default try karo
        debugPrint("Profile $profile nahi mila MikroTik me, default profile check kar raha hun");
        var allProfiles = await client.talk(['/ppp/profile/print']);
        if(allProfiles.isNotEmpty){
          // Agar koi profile hai to pehla use karo, warna error do
          if(allProfiles.length == 1){
            profile = allProfiles[0]['name'] ?? 'default';
          }
        }else{
          client.close();
          return {'ok': false, 'msg': 'Profile $profile MikroTik me nahi bana hua - Pehle Winbox > PPP > Profiles me banao'};
        }
      }

      // Naya user banao
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
      return {'ok': true, 'msg': 'Mikrotik me user ban gaya ($profile) - Ab Dialup karo'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'Add fail: $e - Check karo profile $profile MikroTik me bana hua hai ya nahi'};
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
          'wan_ip': u['caller-id'] ?? '',
          'uptime': u['uptime'],
          'router': 'MikroTik-${cfg['ip']}',
          'bytes': q['bytes'] ?? '0/0',
          'speed': q['rate'] ?? '0/0',
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
      return {'ok': true, 'msg': disable? 'User Disable ho gaya - Net band' : 'User Enable ho gaya - Net chalu'};
    } catch (e) {
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'Error: $e'};
    }
  }

  // NEW: Auto check NAT - ye developer ka kaam nahi lekin help ke liye
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
        return {'ok': true, 'msg': 'NAT Masquerade laga hua hai - Internet chalega'};
      }else{
        return {'ok': false, 'msg': 'NAT Masquerade nahi laga - Winbox > IP > Firewall > NAT me masquerade add karo'};
      }
    } catch(e){
      try{ client?.close(); }catch(_){}
      return {'ok': false, 'msg': 'NAT check fail: $e'};
    }
  }
}