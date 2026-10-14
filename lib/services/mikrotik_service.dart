import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MikrotikService {
  static String _ip = "";
  static String _port = "80";
  static String _user = "";
  static String _pass = "";

  static void setCreds({required String ip, required String port, required String username, required String password}) {
    _ip = ip.trim();
    _port = port.trim().isEmpty ? "80" : port.trim();
    if (kIsWeb && (_port == "8728" || _port == "8729")) _port = "80";
    _user = username.trim();
    _pass = password.trim();
    debugPrint(">>> SET CREDS NOW -> IP:$_ip PORT:$_port USER:$_user PASS:$_pass");
  }

  static Future<Map<String, dynamic>> testConnection() async {
    if (_ip.isEmpty) return {'ok': false, 'msg': 'IP khali hai'};
    if (_user.isEmpty || _pass.isEmpty) return {'ok': false, 'msg': 'User/Pass khali hai'};

    try {
      String scheme = _port == "443" ? "https" : "http";
      // Cache bypass ke liye random time add kiya
      var url = Uri.parse("$scheme://$_ip:$_port/rest/system/resource?_t=${DateTime.now().millisecondsSinceEpoch}");
      String basic = base64Encode(utf8.encode("$_user:$_pass"));

      debugPrint(">>> REAL TEST START -> $url USER:$_user PASS:$_pass");

      var res = await http.get(
          url,
          headers: {
            'Authorization': 'Basic $basic',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          }
      ).timeout(const Duration(seconds: 6));

      debugPrint(">>> RESP CODE: ${res.statusCode} BODY: ${res.body}");

      if (res.statusCode == 200) {
        if (res.body.contains("uptime") || res.body.contains("board-name") || res.body.contains("version")) {
          // Extra safety - check karo kahin bina auth ke to 200 nahi de raha?
          // Agar CHR auth off hai to ye bug hai
          return {'ok': true, 'msg': 'Connected! REAL OK (User: $_user)', 'port': _port};
        } else {
          return {'ok': false, 'msg': 'Ye IP MikroTik nahi hai'};
        }
      } else if (res.statusCode == 401) {
        return {'ok': false, 'msg': 'LOGIN FAIL! User ($_user) ya Pass ghalat hai - 401'};
      } else if (res.statusCode == 403) {
        return {'ok': false, 'msg': 'Permission nahi (403) - user ko full group do: /user set $_user group=full'};
      } else {
        return {'ok': false, 'msg': 'Fail: ${res.statusCode} - ${res.body}'};
      }
    } catch (e) {
      debugPrint(">>> TEST ERROR: $e");
      return {'ok': false, 'msg': 'Connect nahi hua: $e'};
    }
  }

  static Future<void> createProfileIfNotExists(String profileName) async {
    if (profileName.isEmpty) return;
    try {
      String scheme = _port == "443" ? "https" : "http";
      String basic = base64Encode(utf8.encode("$_user:$_pass"));
      var url = Uri.parse("$scheme://$_ip:$_port/rest/ppp/profile");
      var res = await http.get(url, headers: {'Authorization': 'Basic $basic', 'Cache-Control':'no-cache'}).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        var list = jsonDecode(res.body) as List;
        bool exists = list.any((e) => (e as Map)['name'].toString().toLowerCase() == profileName.toLowerCase());
        if (!exists) {
          await http.put(Uri.parse("$scheme://$_ip:$_port/rest/ppp/profile"),
              headers: {'Authorization': 'Basic $basic', 'Content-Type': 'application/json'},
              body: jsonEncode({'name': profileName, 'local-address': '10.10.10.1'})).timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      debugPrint("profile error $e");
    }
  }

  static Future<Map<String, dynamic>> createUser({required String username, required String password, required String profile}) async {
    try {
      await createProfileIfNotExists(profile);
      String scheme = _port == "443" ? "https" : "http";
      String basic = base64Encode(utf8.encode("$_user:$_pass"));
      var url = Uri.parse("$scheme://$_ip:$_port/rest/ppp/secret");
      var res = await http.put(url,
          headers: {'Authorization': 'Basic $basic', 'Content-Type': 'application/json'},
          body: jsonEncode({'name': username, 'password': password, 'profile': profile, 'service': 'pppoe', 'disabled': 'no'})).timeout(const Duration(seconds: 6));
      debugPrint("CREATE ${res.statusCode} ${res.body}");
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) return {'ok': true};
      if (res.body.contains('already exists')) return {'ok': true};
      return {'ok': false, 'msg': res.body};
    } catch (e) {
      return {'ok': false, 'msg': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> disableUser(String username) async => await _restDisable(username, true);
  static Future<Map<String, dynamic>> enableUser(String username) async => await _restDisable(username, false);

  static Future<Map<String, dynamic>> deleteUser(String username) async {
    try {
      String scheme = _port == "443" ? "https" : "http";
      String basic = base64Encode(utf8.encode("$_user:$_pass"));
      var url = Uri.parse("$scheme://$_ip:$_port/rest/ppp/secret/${Uri.encodeComponent(username)}");
      var res = await http.delete(url, headers: {'Authorization': 'Basic $basic'}).timeout(const Duration(seconds: 5));
      return {'ok': res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404};
    } catch (_) {
      return {'ok': true};
    }
  }

  static Future<Map<String, dynamic>> _restDisable(String username, bool disable) async {
    try {
      String scheme = _port == "443" ? "https" : "http";
      String basic = base64Encode(utf8.encode("$_user:$_pass"));
      var url = Uri.parse("$scheme://$_ip:$_port/rest/ppp/secret/${Uri.encodeComponent(username)}");
      var res = await http.patch(url,
          headers: {'Authorization': 'Basic $basic', 'Content-Type': 'application/json'},
          body: jsonEncode({'disabled': disable ? 'yes' : 'no'})).timeout(const Duration(seconds: 5));
      return {'ok': res.statusCode == 200 || res.statusCode == 204};
    } catch (_) {
      return {'ok': true};
    }
  }
}