import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../onboarding/onboarding_screens.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _pwRe = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,72}$');
final _refRe = RegExp(r'^[A-Z]{2,8}-[A-Z0-9]{4}$');

/// Turns Supabase auth errors into simple English.
String friendlyAuth(Object e) {
  final m = e is AuthException ? e.message : e.toString();
  if (RegExp('invalid login', caseSensitive: false).hasMatch(m)) return 'That email or password is not correct. Try again or reset it.';
  if (RegExp('not confirmed', caseSensitive: false).hasMatch(m)) return 'Confirm your email first. We can send you a new code.';
  if (RegExp('banned', caseSensitive: false).hasMatch(m)) return 'This account has been suspended. Contact support.';
  if (RegExp('expired|invalid', caseSensitive: false).hasMatch(m)) return 'That code is not right. Check and try again.';
  if (RegExp('rate|too many', caseSensitive: false).hasMatch(m)) return 'Too many tries. Wait a minute and try again.';
  if (RegExp('socket|network|connection|host', caseSensitive: false).hasMatch(m)) return 'No internet connection. Check your data or Wi-Fi.';
  return m;
}

/// Auth page layout: app bar with back, `.auth-head` (icon/mark, h1, muted line), then a padded form.
class _AuthPage extends StatelessWidget {
  const _AuthPage({required this.title, this.subtitle, this.head, required this.children, this.onBack});
  final String title;
  final Widget? subtitle;
  final Widget? head;
  final List<Widget> children;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    return Scaffold(
      appBar: TopBar(onBack: onBack ?? () => context.canPop() ? context.pop() : context.go('/welcome')),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.s6 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (head != null) ...[head!, const Gap(Space.s3)],
                Text(title, style: context.ty.h1),
                if (subtitle != null) ...[const Gap(Space.s2), DefaultTextStyle(style: context.ty.body.col(context.c.textMuted), child: subtitle!)],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Gap(Space.s4),
                  rm ? children[i] : children[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .1, curve: Motion.out),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shake the form on a failed submit (`.shake`).
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (trigger == 0 || context.reduceMotion) return child;
    return child.animate(key: ValueKey(trigger)).shakeX(hz: 4, amount: 6, duration: 360.ms);
  }
}

Widget _centerLink(BuildContext context, String lead, String link, VoidCallback onTap) => Center(
  child: Text.rich(
    TextSpan(
      style: context.ty.sm.col(context.c.textMuted),
      children: [
        TextSpan(text: '$lead '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(widthFactor: 1, child: Text(link, style: context.ty.sm.bold.col(context.c.link))),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

// ---------------------------------------------------------------- sign up (prototype: signup)
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _ref = TextEditingController();
  bool _agree = false, _busy = false, _refOpen = false, _consentErr = false;
  String? _emailErr, _pwErr, _refErr, _error;
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    final ref = _ref.text.trim().toUpperCase();
    setState(() {
      _error = null;
      _emailErr = _emailRe.hasMatch(email) ? null : 'Enter a valid email, like tolu@gmail.com';
      _pwErr = _pw.text.length < 8
          ? 'Password needs at least 8 characters'
          : _pwRe.hasMatch(_pw.text)
          ? null
          : 'Use letters and at least one number';
      _refErr = ref.isEmpty || _refRe.hasMatch(ref) ? null : 'That referral code does not look right. Check it or leave it empty.';
      _consentErr = !_agree;
    });
    if (_emailErr != null || _pwErr != null || _refErr != null || _consentErr) {
      setState(() => _shake++);
      return;
    }
    setState(() => _busy = true);
    try {
      final len = await this.ref.read(apiProvider).signUp(email: email, password: _pw.text, fullName: '', referralCode: ref);
      if (!mounted) return;
      context.push(
        '/verify',
        extra: VerifyArgs(email: email, type: OtpType.signup, codeLength: len, password: _pw.text),
      );
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _shake++;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final link = context.ty.sm.bold.col(c.link);
    return _AuthPage(
      title: 'Create your account',
      subtitle: const Text('It takes one minute. We will send a code to your email.'),
      onBack: () => context.go('/welcome'),
      children: [
        _Shake(
          trigger: _shake,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(
                  label: 'Email address',
                  hint: 'you@example.com',
                  icon: PhosphorIcons.envelopeSimple(),
                  controller: _email,
                  keyboard: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email],
                  action: TextInputAction.next,
                  error: _emailErr,
                ),
                const Gap(Space.s4),
                Field(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  icon: PhosphorIcons.lockSimple(),
                  password: true,
                  controller: _pw,
                  autofill: const [AutofillHints.newPassword],
                  help: 'Use 8+ characters with a number.',
                  error: _pwErr,
                ),
              ],
            ),
          ),
        ),
        // Referral code (optional, folded like the prototype's <details>)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _refOpen = !_refOpen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.gift(), size: 18, color: c.link),
                    const SizedBox(width: 6),
                    Text('Have a referral code? ', style: link),
                    Text('(optional)', style: context.ty.sm.col(c.textMuted)),
                  ],
                ),
              ),
            ),
            if (_refOpen) ...[
              const Gap(Space.s3),
              Field(
                label: 'Referral code',
                hint: 'e.g. TOLU-7K3P',
                icon: PhosphorIcons.ticket(),
                controller: _ref,
                caps: TextCapitalization.characters,
                maxLength: 12,
                mono: true,
                help: 'Your friend gets rewarded when you finish your first practice test.',
                error: _refErr,
              ),
            ],
          ],
        ),
        CheckRow(
          value: _agree,
          onChanged: (v) => setState(() {
            _agree = v;
            if (v) _consentErr = false;
          }),
          error: _consentErr ? 'Please tick the box to agree to the Terms and Privacy Policy.' : null,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(text: 'Terms', style: link, recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal?p=terms')),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: link, recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal?p=privacy')),
                const TextSpan(text: '. If I am under 18, my parent or guardian agrees too.'),
              ],
            ),
          ),
        ),
        if (_error != null) InfoBanner(kind: BannerKind.err, child: Text(_error!)),
        Btn(_busy ? 'Sending code' : 'Create account', block: true, loading: _busy, onPressed: _submit),
        _centerLink(context, 'Already have an account?', 'Log in', () => context.go('/login')),
      ],
    );
  }
}

// ---------------------------------------------------------------- verify email code (prototype: otp)
class VerifyArgs {
  const VerifyArgs({required this.email, required this.type, required this.codeLength, this.password});
  final String email;
  final OtpType type; // signup only (password reset uses the Reset screen)
  final int codeLength;
  final String? password;
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
  bool _busy = false, _ok = false;
  int _wait = 60, _shake = 0;
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
    if (digits.length < _len) {
      setState(() => _error = 'Copy the $_len-digit code from the email first, then tap Paste code.');
      return;
    }
    _code.text = digits.substring(0, _len);
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != _len) return;
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(email: widget.args.email, token: _code.text, type: widget.args.type);
      ref.read(apiProvider).notify('welcome');
      setState(() => _ok = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) context.go('/setup');
    } catch (e) {
      setState(() {
        _error = friendlyAuth(e);
        _shake++;
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _code.clear();
        _focus.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(apiProvider).signUp(email: widget.args.email, password: widget.args.password!, fullName: '');
      _startTimer();
      if (mounted) toast(context, 'New code sent. Check your inbox and spam folder.', icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill));
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bad = _error != null && _shake > 0;
    return _AuthPage(
      head: IconTile(PhosphorIcons.envelopeSimpleOpen(PhosphorIconsStyle.fill), tone: Tone.blue, size: 56, radius: 16),
      title: 'Check your email',
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Enter the $_len-digit code we sent to '),
            TextSpan(text: widget.args.email, style: context.ty.body.bold.col(c.text)),
            const TextSpan(text: '. It expires in 10 minutes.'),
          ],
        ),
      ),
      children: [
        // One hidden field drives the boxes, so the keyboard, autofill and paste all work.
        _Shake(
          trigger: _shake,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
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
              ),
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Semantics(
                  label: 'Code, ${_code.text.length} of $_len digits entered',
                  child: Row(
                    children: [
                      for (var i = 0; i < _len; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(
                                color: _ok
                                    ? c.success
                                    : bad
                                    ? c.error
                                    : i < _code.text.length
                                    ? c.primary
                                    : i == _code.text.length && _focus.hasFocus
                                    ? c.secondary
                                    : c.borderStrong,
                                width: i <= _code.text.length || _ok || bad ? 2 : 1.5,
                              ),
                            ),
                            child: Text(i < _code.text.length ? _code.text[i] : '', style: context.ty.h1.copyWith(fontSize: _len > 6 ? 20 : 24)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ErrText(_error!),
        Btn('Paste code', kind: BtnKind.tonal, block: true, leading: PhosphorIcons.clipboardText(PhosphorIconsStyle.fill), onPressed: _paste),
        Row(
          children: [
            Expanded(
              child: _wait > 0
                  ? Text.rich(
                      TextSpan(
                        style: context.ty.sm.col(c.textMuted),
                        children: [
                          const TextSpan(text: 'Resend code in '),
                          TextSpan(text: '0:${_wait.toString().padLeft(2, '0')}', style: context.ty.sm.bold.tnum.col(c.text)),
                        ],
                      ),
                    )
                  : Text("Didn't get it?", style: context.ty.sm.col(c.textMuted)),
            ),
            Btn('Resend', kind: BtnKind.ghost, sm: true, onPressed: _wait > 0 ? null : _resend),
          ],
        ),
        InfoBanner(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Copied the code from your email? Tap '),
                TextSpan(text: 'Paste code', style: context.ty.sm.bold.col(c.onSecondarySoft)),
                const TextSpan(text: ', or long-press a box and paste. Check your spam folder too.'),
              ],
            ),
          ),
        ),
        Btn('Change email address', kind: BtnKind.ghost, onPressed: () => context.canPop() ? context.pop() : context.go('/signup')),
      ],
    );
  }
}

// ---------------------------------------------------------------- log in (prototype: login)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(), _pw = TextEditingController();
  String? _emailErr, _pwErr;
  bool _busy = false;
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _emailErr = _emailRe.hasMatch(email) ? null : 'Enter a valid email, like tolu@gmail.com';
      _pwErr = _pw.text.isEmpty ? 'Enter your password' : null;
    });
    if (_emailErr != null || _pwErr != null) return setState(() => _shake++);
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: _pw.text);
      ref.invalidate(profileProvider);
      final next = await nextRoute(ref);
      if (mounted) context.go(next == '/home' ? '/welcome-back' : next);
    } catch (e) {
      setState(() {
        _pwErr = friendlyAuth(e);
        _shake++;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    head: const SizedBox(height: 36, child: Mark(height: 36)),
    title: 'Welcome back',
    subtitle: const Text('Log in to continue your practice.'),
    onBack: () => context.go('/welcome'),
    children: [
      _Shake(
        trigger: _shake,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Field(
                label: 'Email address',
                hint: 'you@example.com',
                icon: PhosphorIcons.envelopeSimple(),
                controller: _email,
                keyboard: TextInputType.emailAddress,
                autofill: const [AutofillHints.email],
                action: TextInputAction.next,
                error: _emailErr,
              ),
              const Gap(Space.s4),
              Field(
                label: 'Password',
                hint: 'Your password',
                icon: PhosphorIcons.lockSimple(),
                password: true,
                controller: _pw,
                autofill: const [AutofillHints.password],
                action: TextInputAction.done,
                onSubmitted: (_) => _login(),
                error: _pwErr,
              ),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: () => context.push('/forgot'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(widthFactor: 1, child: Text('Forgot password?', style: context.ty.sm.bold.col(context.c.link))),
            ),
          ),
        ),
      ),
      Btn('Log in', block: true, loading: _busy, onPressed: _login),
      _centerLink(context, 'New here?', 'Create an account', () => context.go('/signup')),
    ],
  );
}

// ---------------------------------------------------------------- forgot + reset (prototype: forgot, reset)
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailRe.hasMatch(email)) return setState(() => _error = 'Enter a valid email, like tolu@gmail.com');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final len = await ref.read(apiProvider).forgotPassword(email);
      if (mounted) {
        context.push('/reset', extra: ResetArgs(email: email, codeLength: len));
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    head: IconTile(PhosphorIcons.key(PhosphorIconsStyle.fill), tone: Tone.gold, size: 56, radius: 16),
    title: 'Reset your password',
    subtitle: const Text('Enter your email. We will send you a code to set a new password.'),
    children: [
      Field(
        label: 'Email address',
        hint: 'you@example.com',
        icon: PhosphorIcons.envelopeSimple(),
        controller: _email,
        keyboard: TextInputType.emailAddress,
        autofill: const [AutofillHints.email],
        action: TextInputAction.done,
        onSubmitted: (_) => _send(),
        error: _error,
      ),
      Btn('Send reset code', block: true, loading: _busy, onPressed: _send),
    ],
  );
}

class ResetArgs {
  const ResetArgs({required this.email, required this.codeLength});
  final String email;
  final int codeLength;
}

/// Code from the email + new password + confirm, on one screen (prototype: reset).
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, this.args});
  final ResetArgs? args;
  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _code = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  String? _codeErr, _pwErr, _pw2Err;
  bool _busy = false;

  int get _len => (widget.args?.codeLength ?? 6).clamp(6, 10);

  @override
  void dispose() {
    _code.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final args = widget.args;
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    setState(() {
      _codeErr = signedIn || _code.text.trim().length == _len ? null : 'Enter the $_len-digit code from the email';
      _pwErr = _pwRe.hasMatch(_pw.text) ? null : 'Use 8+ characters with a number.';
      _pw2Err = _pw.text == _pw2.text ? null : 'The two passwords are different.';
    });
    if (_codeErr != null || _pwErr != null || _pw2Err != null) return;
    setState(() => _busy = true);
    try {
      if (!signedIn && args != null) {
        await Supabase.instance.client.auth.verifyOTP(email: args.email, token: _code.text.trim(), type: OtpType.recovery);
      }
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _pw.text));
      ref.read(apiProvider).notify('password_changed');
      if (!mounted) return;
      toast(context, 'Password updated. You are logged in.');
      context.go(await nextRoute(ref));
    } catch (e) {
      final m = friendlyAuth(e);
      setState(() => m.contains('code') ? _codeErr = m : _pwErr = m);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsCode = Supabase.instance.client.auth.currentSession == null;
    return _AuthPage(
      title: 'Create a new password',
      subtitle: Text(needsCode ? 'Enter the code from your email and your new password.' : 'Choose your new password.'),
      children: [
        if (needsCode)
          Field(
            label: '$_len-digit code',
            hint: '0' * _len,
            icon: PhosphorIcons.hash(),
            controller: _code,
            keyboard: TextInputType.number,
            autofill: const [AutofillHints.oneTimeCode],
            maxLength: _len,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            error: _codeErr,
          ),
        Field(
          label: 'New password',
          hint: 'At least 8 characters',
          icon: PhosphorIcons.lockSimple(),
          password: true,
          controller: _pw,
          autofill: const [AutofillHints.newPassword],
          help: 'Use 8+ characters with a number.',
          error: _pwErr,
        ),
        Field(label: 'Confirm new password', hint: 'Type it again', icon: PhosphorIcons.lockSimple(), password: true, controller: _pw2, error: _pw2Err),
        Btn('Save new password', block: true, loading: _busy, onPressed: _save),
      ],
    );
  }
}
