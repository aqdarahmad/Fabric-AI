import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// تسجيل دخول بسيط عبر سيرفر Fabric-AI (server/auth.js) بدل Firebase.
class AuthService {
  static const String _configuredBase = String.fromEnvironment('API_BASE_URL');
  static Box get _box => Hive.box('fabricBox');

  static String get baseUrl {
    if (_configuredBase.isNotEmpty) {
      return _configuredBase.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return Uri.base.origin;
    throw AuthException('API_BASE_URL is not configured for this build.');
  }

  static String? get token => _box.get('authToken') as String?;
  static String? get email => _box.get('authEmail') as String?;
  static bool get isLoggedIn => (token ?? '').isNotEmpty;

  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (isLoggedIn) 'Authorization': 'Bearer $token',
  };

  static Future<void> signUp(String email, String password) =>
      _authenticate('signup', email, password);

  static Future<void> login(String email, String password) =>
      _authenticate('login', email, password);

  static Future<void> _authenticate(
    String path,
    String email,
    String password,
  ) async {
    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$baseUrl/api/auth/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AuthException('Cannot reach the server. Please try again.');
    }
    final data = _decode(r.body);
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw AuthException(
        data['error']?.toString() ?? 'An error occurred. Please try again.',
      );
    }
    await _box.put('authToken', data['token']);
    await _box.put('authEmail', data['email']);
  }

  static Future<void> logout() async {
    await _box.delete('authToken');
    await _box.delete('authEmail');
  }

  static Future<void> deleteAccount() async {
    final r = await http
        .delete(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: authHeaders,
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw AuthException(
        _decode(r.body)['error']?.toString() ?? 'Could not delete the account.',
      );
    }
    await logout();
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (_) {
      return {};
    }
  }
}
