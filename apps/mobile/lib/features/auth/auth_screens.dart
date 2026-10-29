import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../onboarding/onboarding_screens.dart';
import '../shell/shell.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _pwRe = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,72}$');

/// Turns Supabase auth errors into simple English.
String friendlyAuth(Object e) {
  final m = e is AuthException ? e.message : e.toString();
  if (RegExp('invalid login', caseSensitive: false).hasMatch(m)) return 'Email or password is not correct.';
  if (RegExp('not confirmed', caseSensitive: false).hasMatch(m)) return 'Confirm your email first. We can send you a new code.';
  if (RegExp('banned', caseSensitive: false).hasMatch(m)) return 'This account has been suspended. Contact support.';
  if (RegExp('expired|invalid', caseSensitive: false).hasMatch(m)) return 'That code is not right or has expired. Ask for a new one.';
  if (RegExp('rate|too many', caseSensitive: false).hasMatch(m)) return 'Too many tries. Wait a minute and try again.';
  if (RegExp('socket|network|connection|host', caseSensitive: false).hasMatch(m)) return 'No internet connection. Check your data or Wi-Fi.';
  return m;
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, this.subtitle, required this.children, this.back = true});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: back),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s7),
        children: [
          Text(title, style: context.t.headlineMedium),
          if (subtitle != null) ...[gap2, Text(subtitle!, style: context.t.bodyMedium?.copyWith(color: context.c.textMuted))],
          gap6,
          ...children,
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String? text;
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: Space.s3),
          child: Text(
            text!,
            style: context.t.bodyMedium?.copyWith(color: context.c.error, fontWeight: FontWeight.w700),
            semanticsLabel: 'Error: $text',
          ),
        );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, this.label = 'Password', this.newPassword = false});
  final TextEditingController controller;
  final String label;
  final bool newPassword;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: !_show,
    autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.newPassword ? 'At least 8 characters with letters and numbers' : null,
      suffixIcon: IconButton(
        tooltip: _show ? 'Hide password' : 'Show password',
        icon: Icon(_show ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye()),
        onPressed: () => setState(() => _show = !_show),
      ),
    ),
  );
}

Widget _busy(bool busy, String label) =>
    busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(label);

// ---------------------------------------------------------------- sign up
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController(), _ref = TextEditingController();
  bool _consent = false, _busyState = false;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    setState(
      () => _error = _name.text.trim().length < 2
          ? 'Enter your full name.'
          : !_emailRe.hasMatch(email)
          ? 'Enter a valid email address.'
          : !_pwRe.hasMatch(_pw.text)
          ? 'Use at least 8 characters with letters and numbers.'
          : !_consent
          ? 'Please accept the Terms and Privacy Policy to continue.'
          : null,
    );
    if (_error != null) return;
    setState(() => _busyState = true);
    try {
      final len = await ref.read(apiProvider).signUp(email: email, password: _pw.text, fullName: _name.text.trim(), referralCode: _ref.text.trim());
      if (!mounted) return;
      context.push(
        '/verify',
        extra: VerifyArgs(email: email, type: OtpType.signup, codeLength: len, password: _pw.text, fullName: _name.text.trim()),
      );
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyState = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final link = TextStyle(color: c.link, fontWeight: FontWeight.w700);
    return _AuthFrame(
      title: 'Create your account',
      subtitle: 'Free to start. We will email you a code to confirm.',
      children: [
        AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              gap4,
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              gap4,
              _PasswordField(controller: _pw, newPassword: true),
              gap4,
              TextField(
                controller: _ref,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Referral code (optional)'),
              ),
            ],
          ),
        ),
        gap4,
        // Consent is required (D-019): the button stays usable but explains what is missing.
        InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => setState(() => _consent = !_consent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: _consent, onChanged: (v) => setState(() => _consent = v ?? false)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: context.t.bodyMedium,
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(text: 'Terms', style: link, recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal?p=terms')),
                          const TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: link, recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal?p=privacy')),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ErrorText(_error),
        gap5,
        FilledButton(onPressed: _busyState ? null : _submit, child: _busy(_busyState, 'Create account')),
        gap3,
        TextButton(onPressed: () => context.go('/login'), child: const Text('I already have an account')),
      ],
    );
  }
}

// ---------------------------------------------------------------- verify code
class VerifyArgs {
  const VerifyArgs({required this.email, required this.type, required this.codeLength, this.password, this.fullName});
  final String email;
  final OtpType type; // signup or recovery
  final int codeLength;
  final String? password, fullName;
}

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.args});
  final VerifyArgs args;
  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busyState = false;
  int _wait = 60;
  Timer? _t;

  int get _len => widget.args.codeLength.clamp(6, 10);

  @override
  void initState() {
    super.initState();
    _startTimer();
    _code.addListener(() {
      setState(() {});
      if (_code.text.length == _len) _verify();
    });
  }

  void _startTimer() {
    _t?.cancel();
    setState(() => _wait = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = (_wait - 1).clamp(0, 60));
      if (_wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (d?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length >= _len) _code.text = digits.substring(0, _len);
  }

  Future<void> _verify() async {
    if (_busyState || _code.text.length != _len) return;
    setState(() {
      _busyState = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(email: widget.args.email, token: _code.text, type: widget.args.type);
      final api = ref.read(apiProvider);
      if (!mounted) return;
      if (widget.args.type == OtpType.recovery) {
        context.go('/reset');
      } else {
        api.notify('welcome');
        context.go('/setup');
      }
    } catch (e) {
      setState(() {
        _error = friendlyAuth(e);
        _code.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _busyState = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      final api = ref.read(apiProvider);
      if (widget.args.type == OtpType.recovery) {
        await api.forgotPassword(widget.args.email);
      } else {
        await api.signUp(email: widget.args.email, password: widget.args.password!, fullName: widget.args.fullName!);
      }
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code sent. Check your email.')));
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _AuthFrame(
      title: 'Check your email',
      subtitle: 'We sent a $_len-digit code to ${widget.args.email}. It may take a minute; check spam too.',
      children: [
        // One hidden field drives the boxes, so the keyboard, autofill and paste all work.
        Stack(
          children: [
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _code,
                focusNode: _focus,
                autofocus: true,
                maxLength: _len,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            GestureDetector(
              onTap: () => _focus.requestFocus(),
              child: Semantics(
                label: 'Code, ${_code.text.length} of $_len digits entered',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _len; i++)
                      Container(
                        width: _len > 6 ? 36 : 46,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: i == _code.text.length ? c.secondary : c.borderStrong, width: i == _code.text.length ? 2 : 1.5),
                        ),
                        child: Text(i < _code.text.length ? _code.text[i] : '', style: context.t.headlineSmall),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _ErrorText(_error),
        gap4,
        Row(
          children: [
            TextButton.icon(onPressed: _paste, icon: Icon(PhosphorIcons.clipboardText()), label: const Text('Paste code')),
            const Spacer(),
            TextButton(onPressed: _wait > 0 ? null : _resend, child: Text(_wait > 0 ? 'Resend in ${_wait}s' : 'Send a new code')),
          ],
        ),
        gap4,
        FilledButton(onPressed: _code.text.length == _len && !_busyState ? _verify : null, child: _busy(_busyState, 'Continue')),
      ],
    );
  }
}

// ---------------------------------------------------------------- log in
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(), _pw = TextEditingController();
  String? _error;
  bool _busyState = false;

  Future<void> _login() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email) || _pw.text.isEmpty) return setState(() => _error = 'Enter your email and password.');
    setState(() {
      _busyState = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: _pw.text);
      ref.invalidate(profileProvider);
      final next = await nextRoute(ref);
      if (mounted) context.go(next == '/home' ? '/welcome-back' : next);
    } catch (e) {
      setState(() => _error = friendlyAuth(e));
    } finally {
      if (mounted) setState(() => _busyState = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: 'Welcome back',
    subtitle: 'Log in to continue practising.',
    back: false,
    children: [
      AutofillGroup(
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            gap4,
            _PasswordField(controller: _pw),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?')),
      ),
      _ErrorText(_error),
      gap4,
      FilledButton(onPressed: _busyState ? null : _login, child: _busy(_busyState, 'Log in')),
      gap3,
      OutlinedButton(onPressed: () => context.go('/signup'), child: const Text('Create an account')),
    ],
  );
}

// ---------------------------------------------------------------- forgot / new password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _error;
  bool _busyState = false;

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return setState(() => _error = 'Enter a valid email address.');
    setState(() {
      _busyState = true;
      _error = null;
    });
    try {
      final len = await ref.read(apiProvider).forgotPassword(email);
      if (mounted) {
        context.push(
          '/verify',
          extra: VerifyArgs(email: email, type: OtpType.recovery, codeLength: len),
        );
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyState = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: 'Reset your password',
    subtitle: 'Enter your email. If it has an account, we will send you a code.',
    children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      _ErrorText(_error),
      gap5,
      FilledButton(onPressed: _busyState ? null : _send, child: _busy(_busyState, 'Send code')),
    ],
  );
}

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});
  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _pw = TextEditingController(), _pw2 = TextEditingController();
  String? _error;
  bool _busyState = false;

  Future<void> _save() async {
    if (!_pwRe.hasMatch(_pw.text)) return setState(() => _error = 'Use at least 8 characters with letters and numbers.');
    if (_pw.text != _pw2.text) return setState(() => _error = 'The two passwords are different.');
    setState(() {
      _busyState = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _pw.text));
      ref.read(apiProvider).notify('password_changed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
      context.go(await nextRoute(ref));
    } catch (e) {
      setState(() => _error = friendlyAuth(e));
    } finally {
      if (mounted) setState(() => _busyState = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    title: 'Choose a new password',
    back: false,
    children: [
      _PasswordField(controller: _pw, label: 'New password', newPassword: true),
      gap4,
      _PasswordField(controller: _pw2, label: 'Type it again'),
      _ErrorText(_error),
      gap5,
      FilledButton(onPressed: _busyState ? null : _save, child: _busy(_busyState, 'Save password')),
    ],
  );
}
