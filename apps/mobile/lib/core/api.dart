import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'device.dart';

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
      final r = await _http.post(Uri.parse('${Config.apiBase}$path'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 25));
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
      'email': email,
      'password': password,
      'fullName': fullName,
      'consent': true,
      if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
      // D-079: the server refuses sign-up on a banned phone.
      'deviceIds': (await DeviceCheck.ids()).list.whereType<String>().toList(),
    });
    return (d['codeLength'] as num?)?.toInt() ?? 6;
  }

  /// Always succeeds the same way (privacy). Returns the code length when a code was sent.
  Future<int> forgotPassword(String email) async {
    final d = await _post('/api/auth/forgot-password', {'email': email});
    return (d['codeLength'] as num?)?.toInt() ?? 6;
  }

  Future<void> notify(String event) async {
    try {
      await _post('/api/auth/notify', {'event': event}, auth: true);
    } catch (_) {
      // Notices are best-effort.
    }
  }

  /// A short-lived link to a question image. The server checks the student may see that question first.
  Future<String> signImage(String key) async {
    final d = await _post('/api/images/sign', {'key': key}, auth: true);
    return d['url'] as String;
  }

  /// A 10-minute upload link for the student's profile photo: returns (key, url). D-063.
  Future<(String, String)> avatarUploadLink(int size) async {
    final d = await _post('/api/account/avatar', {'contentType': 'image/jpeg', 'size': size}, auth: true);
    return (d['key'] as String, d['url'] as String);
  }

  /// Upload link for a challenge appeal screenshot (D-073), saved under the student's own `a/<id>/` folder.
  Future<(String, String)> appealUploadLink(int size, String contentType) async {
    final d = await _post('/api/account/avatar', {'contentType': contentType, 'size': size, 'purpose': 'appeal'}, auth: true);
    return (d['key'] as String, d['url'] as String);
  }

  /// A short-lived link to one file of a study item (360 / 720 video, pdf, cover). The server checks the
  /// student's plan first; a locked item comes back as status 403.
  Future<String> studyFile(String id, String file) async {
    final d = await _post('/api/study/file', {'id': id, 'file': file}, auth: true);
    return d['url'] as String;
  }

  /// Step 1 of deleting an account (D-126): sends the reason and emails a 6-digit code. Returns the masked email.
  Future<String> deleteAccountStart({required String reason, String note = ''}) async {
    final d = await _post('/api/account/delete/start', {'reason': reason, 'note': note}, auth: true);
    return (d['email'] as String?) ?? 'your email';
  }

  /// Step 2: deletes the account with the emailed code.
  Future<void> deleteAccount({required String code}) => _post('/api/account/delete', {'confirm': 'DELETE', 'code': code, 'via': 'app'}, auth: true);

  /// Under 13 (D-109): the account just made is deleted at once; the server checks the age or that it is brand new.
  Future<void> deleteUnder13() => _post('/api/account/delete', {'confirm': 'DELETE', 'via': 'under13'}, auth: true);

  /// A one-time code (2 minutes, works once) that opens the payment website already logged in (D-115).
  Future<String?> webHandoff({String? plan}) async {
    final d = await _post('/api/web/handoff', {'plan': ?plan}, auth: true);
    return d['code'] as String?;
  }

  /// Students aged 13 to 17: email the parent's or guardian's welcome notice (D-109). Returns the message to show.
  Future<String> sendGuardianNotice(String email) async {
    final d = await _post('/api/account/guardian', {'email': email}, auth: true);
    return (d['message'] as String?) ?? 'Email sent.';
  }
}
