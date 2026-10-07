import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:router_os_client/router_os_client.dart';

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

  // REAL TEST - ROS 6 + 7 dono
  static Future<Map<String, dynamic>> testConnection() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP khali hai'};

    if (cfg['port'] == '80' || cfg['port'] == '443') {
      try {
        var url = Uri.parse("http://${cfg['ip']}:${cfg['port']}/rest/system/resource");
        var res = await http.get(url, headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${cfg['user']}:${cfg['pass']}'))}',
        }).timeout(Duration(seconds: 5));
        if (res.statusCode == 200) return {'ok': true, 'msg': 'Connected REST OK'};
        return {'ok': false, 'msg': 'REST Fail ${res.statusCode}. Port 8728 use karo'};
      } catch (e) {
        return {'ok': false, 'msg': 'REST Fail: $e'};
      }
    }

    try {
      final client = RouterOSClient(
        address: cfg['ip']!,
        user: cfg['user']!,
        password: cfg['pass']!,
        useSsl: cfg['port'] == '8729',
      );
      bool ok = await client.login();
      if (!ok) {
        client.close();
        return {'ok': false, 'msg': 'Login fail'};
      }
      var data = await client.talk(['/system/resource/print']);
      client.close();
      String board = data.isNotEmpty? data[0]['board-name']?? 'Mikrotik' : 'Mikrotik';
      return {'ok': true, 'msg': 'Connected! $board - Port ${cfg['port']} OK'};
    } catch (e) {
      return {'ok': false, 'msg': 'API Fail: $e. IP>Services me API ON karo'};
    }
  }

  static Future<List<Map<String, dynamic>>> getOnlineUsersDetailed() async {
    var cfg = await _getConfig();
    final client = RouterOSClient(address: cfg['ip']!, user: cfg['user']!, password: cfg['pass']!);
    await client.login();
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
  }

  static Future<Map<String, dynamic>> addPppUser({required String username, required String password, required String profile}) async {
    var cfg = await _getConfig();
    try {
      final client = RouterOSClient(address: cfg['ip']!, user: cfg['user']!, password: cfg['pass']!);
      await client.login();
      await client.talk(['/ppp/secret/add', '=name=$username', '=password=$password', '=profile=$profile', '=service=pppoe']);
      client.close();
      return {'ok': true, 'msg': 'Mikrotik me user ban gaya'};
    } catch (e) {
      return {'ok': false, 'msg': 'Add fail: $e'};
    }
  }

  static Future<Map<String, dynamic>> disableUser(String username) async => _setDisabled(username, true);
  static Future<Map<String, dynamic>> enableUser(String username) async => _setDisabled(username, false);

  static Future<Map<String, dynamic>> _setDisabled(String username, bool disable) async {
    var cfg = await _getConfig();
    try {
      final client = RouterOSClient(address: cfg['ip']!, user: cfg['user']!, password: cfg['pass']!);
      await client.login();
      var list = await client.talk(['/ppp/secret/print', '?name=$username']);
      if (list.isEmpty) {
        client.close();
        return {'ok': false, 'msg': 'User nahi mila'};
      }
      String id = list[0]['.id']!;
      await client.talk(['/ppp/secret/set', '=.id=$id', '=disabled=${disable? 'yes' : 'no'}']);
      if (disable) {
        var active = await client.talk(['/ppp/active/print', '?name=$username']);
        for (var a in active) {
          await client.talk(['/ppp/active/remove', '=.id=${a['.id']}']);
        }
      }
      client.close();
      return {'ok': true, 'msg': disable? 'User Disable ho gaya' : 'User Enable ho gaya'};
    } catch (e) {
      return {'ok': false, 'msg': 'Error: $e'};
    }
  }
}