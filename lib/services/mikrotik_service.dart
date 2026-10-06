import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MikrotikService {
  static Future<Map<String, String>> _getConfig() async {
    var p = await SharedPreferences.getInstance();
    return {
      'ip': (p.getString('mt_ip')?? '').trim(),
      'user': (p.getString('mt_user')?? 'admin').trim(),
      'pass': p.getString('mt_pass')?? '',
      'port': (p.getString('mt_port')?? '80').trim(),
    };
  }

  static String _basicAuth(String user, String pass) {
    return 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
  }

  static Uri _buildUrl(String ip, String port, String path) {
    // http://192.168.88.1:80/rest/...
    return Uri.parse("http://$ip:$port$path");
  }

  // REAL CONNECTION TEST - Yehi asal test hai
  static Future<Map<String, dynamic>> testConnection() async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'IP khali hai'};

    var url = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/system/resource');
    try {
      var res = await http.get(url, headers: {
        'Authorization': _basicAuth(cfg['user']!, cfg['pass']!),
      }).timeout(Duration(seconds: 5));

      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        String board = data['board-name']?? 'Mikrotik';
        String version = data['version']?? '';
        return {'ok': true, 'msg': 'Connected! $board - $version'};
      } else if (res.statusCode == 401) {
        return {'ok': false, 'msg': 'Username/Password galat hai'};
      } else if (res.statusCode == 404) {
        return {'ok': false, 'msg': 'REST API nahi mila. RouterOS 7 hai? /ip/service me www enable karo'};
      } else {
        return {'ok': false, 'msg': 'Error ${res.statusCode}: ${res.body}'};
      }
    } catch (e) {
      return {'ok': false, 'msg': 'Connect nahi hua: $e. IP ping ho raha? Port 80 open hai?'};
    }
  }

  // ADD USER - Improved
  static Future<Map<String, dynamic>> addPppUser({required String username, required String password, required String profile}) async {
    var cfg = await _getConfig();
    if (cfg['ip']!.isEmpty) return {'ok': false, 'msg': 'Pehle Setting me IP save karo'};
    var url = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/ppp/secret');
    try {
      var res = await http.put(url,
          headers: {'Authorization': _basicAuth(cfg['user']!, cfg['pass']!), 'Content-Type': 'application/json'},
          body: jsonEncode({"name": username, "password": password, "profile": profile, "service": "pppoe"})).timeout(Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'ok': true, 'msg': 'Mikrotik me user ban gaya'};
      } else {
        return {'ok': false, 'msg': 'Add fail: ${res.body}'};
      }
    } catch (e) {
      return {'ok': false, 'msg': 'Error: $e'};
    }
  }

  // DISABLE
  static Future<Map<String, dynamic>> disableUser(String username) async {
    return _setDisabled(username, true);
  }

  // ENABLE
  static Future<Map<String, dynamic>> enableUser(String username) async {
    return _setDisabled(username, false);
  }

  static Future<Map<String, dynamic>> _setDisabled(String username, bool disable) async {
    var cfg = await _getConfig();
    try {
      var getUrl = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/ppp/secret?name=$username');
      var getRes = await http.get(getUrl, headers: {'Authorization': _basicAuth(cfg['user']!, cfg['pass']!)}).timeout(Duration(seconds: 5));
      if (getRes.statusCode!= 200) return {'ok': false, 'msg': 'User search fail: ${getRes.statusCode}'};

      var list = jsonDecode(getRes.body) as List;
      if (list.isEmpty) return {'ok': false, 'msg': 'User Mikrotik me nahi mila: $username'};
      String id = list[0]['.id'];

      var patchUrl = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/ppp/secret/$id');
      var res = await http.patch(patchUrl,
          headers: {'Authorization': _basicAuth(cfg['user']!, cfg['pass']!), 'Content-Type': 'application/json'},
          body: jsonEncode({"disabled": disable? "yes" : "no"})).timeout(Duration(seconds: 5));

      if (disable) await kickActiveUser(username);

      if (res.statusCode == 200) {
        return {'ok': true, 'msg': disable? 'User Disable ho gaya' : 'User Enable ho gaya'};
      } else {
        return {'ok': false, 'msg': 'Fail: ${res.body}'};
      }
    } catch (e) {
      return {'ok': false, 'msg': 'Error: $e'};
    }
  }

  static Future<bool> kickActiveUser(String username) async {
    var cfg = await _getConfig();
    try {
      var url = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/ppp/active?name=$username');
      var res = await http.get(url, headers: {'Authorization': _basicAuth(cfg['user']!, cfg['pass']!)}).timeout(Duration(seconds: 5));
      var list = jsonDecode(res.body) as List;
      for (var item in list) {
        String id = item['.id'];
        var removeUrl = _buildUrl(cfg['ip']!, cfg['port']!, '/rest/ppp/active/$id');
        await http.delete(removeUrl, headers: {'Authorization': _basicAuth(cfg['user']!, cfg['pass']!)});
      }
      return true;
    } catch (e) { return false; }
  }
}