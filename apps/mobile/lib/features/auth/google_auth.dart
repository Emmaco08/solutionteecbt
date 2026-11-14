import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/platform.dart';
import '../../core/providers.dart';
import '../../ui/kit.dart';

/// "Continue with Google" (D-087). Shown only when Admin → Flags & settings → Sign in with Google is on
/// and a Web client ID is saved. The client secret never comes to the app (it lives in Supabase Auth).
({bool on, String clientId}) googleAuthConfig(WidgetRef ref) {
  final g = ref.watch(appSettingsProvider).value?['google_auth'];
  final id = g is Map ? '${g['web_client_id'] ?? ''}'.trim() : '';
  // Windows (D-166): only once the admin turns "Also on the Windows app" on (the browser redirect must be allowed first).
  final desktopOk = !isDesktop || (g is Map && g['desktop'] == true);
  return (on: g is Map && g['enabled'] == true && id.isNotEmpty && desktopOk, clientId: id);
}

/// What happened after the Google sheet closed.
enum GoogleResult { signedIn, created, canceled }

String _nonce() {
  final r = Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
}

/// Opens Google's account picker, then signs in to SolutionTee with the Google ID token.
/// A one-time nonce ties the token to this sign-in, so a copied token cannot be replayed.
/// New accounts get the Terms consent date and the referral code (if one was typed).
Future<GoogleResult> signInWithGoogle(WidgetRef ref, {required String clientId, String? referralCode}) async {
  if (isDesktop) {
    final u = await _desktopGoogle();
    return u == null ? GoogleResult.canceled : _afterSignIn(ref, u, referralCode);
  }
  final raw = _nonce();
  final g = GoogleSignIn.instance;
  // initialize() carries the nonce, so it runs before every sign-in (on Android it only stores these values).
  await g.initialize(serverClientId: clientId, nonce: sha256.convert(utf8.encode(raw)).toString());
  GoogleSignInAccount account;
  try {
    // Sign out of Google first so the student can pick which Google account to use.
    await g.signOut().catchError((_) {});
    account = await g.authenticate(scopeHint: const ['email', 'profile']);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return GoogleResult.canceled;
    throw ApiError(
      e.code == GoogleSignInExceptionCode.clientConfigurationError || e.code == GoogleSignInExceptionCode.providerConfigurationError
          ? 'Google sign-in is not set up correctly yet. Use your email and password for now.'
          : 'Google sign-in did not work. Check your internet and try again.',
    );
  }
  final idToken = account.authentication.idToken;
  if (idToken == null) throw ApiError('Google did not send your details. Try again.');

  final sb = Supabase.instance.client;
  final AuthResponse res;
  try {
    res = await sb.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken, nonce: raw);
  } on AuthException catch (e) {
    throw ApiError(
      RegExp('banned', caseSensitive: false).hasMatch(e.message)
          ? 'This account is blocked. Contact support.'
          : 'We could not sign you in with Google. Try again, or use your email and password.',
    );
  }
  return _afterSignIn(ref, res.user, referralCode);
}

/// Shared by the phone and desktop flows: consent date and referral for a brand-new account.
Future<GoogleResult> _afterSignIn(WidgetRef ref, User? user, String? referralCode) async {
  if (user == null) throw ApiError('We could not sign you in with Google. Try again.');
  final sb = Supabase.instance.client;

  // A brand-new account (created in the last few minutes, never signed in before this).
  final created = DateTime.tryParse(user.createdAt);
  final isNew = created != null && DateTime.now().toUtc().difference(created.toUtc()).inMinutes < 5 && user.userMetadata?['terms_accepted_at'] == null;
  if (isNew) {
    try {
      await sb.auth.updateUser(UserAttributes(data: {'terms_accepted_at': DateTime.now().toUtc().toIso8601String(), 'signed_up_with': 'google'}));
    } catch (_) {}
    final code = referralCode?.trim().toUpperCase() ?? '';
    if (code.isNotEmpty) {
      try {
        await sb.rpc('referral_apply', params: {'p_code': code});
      } catch (_) {}
    }
    ref.read(apiProvider).notify('welcome');
  }
  ref.invalidate(profileProvider);
  return isNew ? GoogleResult.created : GoogleResult.signedIn;
}

/// Desktop: Google in the student's browser (PKCE). Supabase sends the browser back to a one-off page on this computer
/// (http://localhost:53682), which hands the code to the app; the code verifier never leaves the app (D-166).
Future<User?> _desktopGoogle() async {
  final sb = Supabase.instance.client;
  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _desktopPort);
  } catch (_) {
    throw ApiError('Google sign-in is busy on this computer. Close other SolutionTee windows and try again.');
  }
  try {
    final r = await sb.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: 'http://localhost:$_desktopPort/auth/callback',
      queryParams: const {'prompt': 'select_account'},
    );
    if (!await launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication)) throw ApiError('Could not open your browser. Try again.');
    String? code, error;
    await for (final req in server.timeout(const Duration(minutes: 5))) {
      if (req.uri.path != '/auth/callback') {
        req.response
          ..statusCode = 404
          ..close();
        continue;
      }
      code = req.uri.queryParameters['code'];
      error = req.uri.queryParameters['error_description'] ?? req.uri.queryParameters['error'];
      req.response
        ..headers.contentType = ContentType.html
        ..write(_doneHtml(code != null))
        ..close();
      break;
    }
    if (code == null) {
      if (error != null && error.contains('denied')) return null;
      throw ApiError('Google sign-in did not finish. Try again, or use your email and password.');
    }
    final s = await sb.auth.exchangeCodeForSession(code);
    return s.session.user;
  } on TimeoutException {
    throw ApiError('Google sign-in took too long. Try again.');
  } on AuthException catch (e) {
    throw ApiError(
      RegExp('banned', caseSensitive: false).hasMatch(e.message)
          ? 'This account is blocked. Contact support.'
          : 'We could not sign you in with Google. Try again.',
    );
  } finally {
    await server.close(force: true);
  }
}

const _desktopPort = 53682;

String _doneHtml(bool ok) =>
    '''<!doctype html><html><head><meta charset="utf-8"><title>SolutionTee CBT</title>
<style>body{margin:0;height:100vh;display:grid;place-items:center;background:#0B1F44;color:#fff;font-family:Segoe UI,system-ui,sans-serif}
.c{background:#13306A;padding:40px 48px;border-radius:24px;text-align:center;max-width:420px}h1{margin:0 0 8px;font-size:26px}p{color:#C9D5EA;margin:0}
.d{width:64px;height:64px;border-radius:50%;background:#F2B233;margin:0 auto 20px;display:grid;place-items:center;font-size:34px;color:#0B1F44}</style></head>
<body><div class="c"><div class="d">${ok ? '&#10003;' : '!'}</div><h1>${ok ? 'You are signed in' : 'Sign-in did not finish'}</h1>
<p>${ok ? 'Go back to the SolutionTee CBT app. You can close this tab.' : 'Go back to the app and try again.'}</p></div></body></html>''';

/// The "Continue with Google" button with Google's official G (assets/third_party, from Google's sign-in assets).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.busy = false, this.label = 'Continue with Google'});
  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  @override
  Widget build(BuildContext context) => Btn(
    label,
    kind: BtnKind.google,
    block: true,
    loading: busy,
    lead: Image.asset('assets/third_party/google_g.png', width: 22, height: 22, filterQuality: FilterQuality.medium, semanticLabel: 'Google'),
    onPressed: onPressed,
  );
}
