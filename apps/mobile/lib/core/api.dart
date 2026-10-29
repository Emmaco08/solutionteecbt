import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// A friendly error the UI can show as-is.
class ApiError implements Exception {
  ApiError(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// Calls to the SolutionTee website API (docs/AUTH_EMAIL.md). The website holds the secret keys;
/// the app only ever sends the user's own access token.
class WebApi {
  WebApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body, {bool auth = false}) async {
    final headers = {'content-type': 'application/json'};
    if (auth) {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw ApiError('Please log in again.', status: 401);
      headers['authorization'] = 'Bearer $token';
    }
    try {
      final r = await _http
          .post(Uri.parse('${Config.apiBase}$path'), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode >= 400) throw ApiError((data['error'] as String?) ?? 'Something went wrong. Try again.', status: r.statusCode);
      return data;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('No internet connection. Check your data or Wi-Fi and try again.');
    }
  }

  /// Creates the account (unconfirmed) and emails a code. Returns how many digits the code has.
  Future<int> signUp({required String email, required String password, required String fullName, String? referralCode}) async {
    final d = await _post('/api/auth/sign-up', {
      'email': email, 'password': password, 'fullName': fullName, 'consent': true,
      if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
    });
    return (d['codeLength'] as num?)?.toInt() ?? 6;
  }

  /// Always succeeds the same way (privacy). Returns the code length when a code was sent.
  Future<int> forgotPassword(String email) async {
    final d = await _post('/api/auth/forgot-password', {'email': email});
    return (d['codeLength'] as num?)?.toInt() ?? 8;
  }

  Future<void> notify(String event) async {
    try {
      await _post('/api/auth/notify', {'event': event}, auth: true);
    } catch (_) {
      // Notices are best-effort.
    }
  }

  Future<void> deleteAccount() => _post('/api/account/delete', {'confirm': 'DELETE'}, auth: true);
}
