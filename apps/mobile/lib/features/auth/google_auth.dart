import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// "Continue with Google" (D-087). Shown only when Admin → Flags & settings → Sign in with Google is on
/// and a Web client ID is saved. The client secret never comes to the app (it lives in Supabase Auth).
({bool on, String clientId}) googleAuthConfig(WidgetRef ref) {
  final g = ref.watch(appSettingsProvider).value?['google_auth'];
  final id = g is Map ? '${g['web_client_id'] ?? ''}'.trim() : '';
  return (on: g is Map && g['enabled'] == true && id.isNotEmpty, clientId: id);
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
  final user = res.user;
  if (user == null) throw ApiError('We could not sign you in with Google. Try again.');

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

/// The white "Continue with Google" button (Google's own G logo glyph from the icon font, not redrawn).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.busy = false, this.label = 'Continue with Google'});
  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Btn(label, kind: BtnKind.google, block: true, loading: busy, leading: PhosphorIcons.googleLogo(PhosphorIconsStyle.fill), onPressed: onPressed);
}
