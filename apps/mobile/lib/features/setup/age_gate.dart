import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart' show askBirthYearOnce;
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../profile/profile_screens.dart' show signOutAndWipe;

/// Age rules (lawyer's decisions of 8 Nov 2026, D-109): under 13 no account; 13 to 17 a parent or guardian gets a
/// welcome notice with a "turn off" link; 18 and over a normal account. Age = this year minus the year of birth.
const minAge = 13, adultAge = 18;
int ageFromYear(int year) => DateTime.now().year - year;

/// Asks the server what the signed-in student must do about age, and opens the right screen.
/// Returns true when the student may carry on. Offline or any error: carry on (the server keeps the rules).
Future<bool> checkAge(BuildContext context, WidgetRef ref) async {
  try {
    final j = await ref.read(supabaseProvider).rpc('age_status').timeout(const Duration(seconds: 12));
    final s = Map<String, dynamic>.from(j as Map);
    if (!context.mounted) return false;
    switch (s['status']) {
      case 'unknown':
        // Accounts from before the age rules: the year of birth is asked once, then checked again.
        await askBirthYearOnce(context, ref, force: true);
        if (!context.mounted) return false;
        final again = Map<String, dynamic>.from(await ref.read(supabaseProvider).rpc('age_status') as Map);
        if (!context.mounted) return false;
        if (again['status'] == 'guardian_needed') {
          context.go('/guardian');
          return false;
        }
        return again['status'] == 'ok';
      case 'under_13':
        await blockUnder13(context, ref);
        return false;
      case 'guardian_needed':
        context.go('/guardian');
        return false;
      case 'paused':
        context.go('/account-paused');
        return false;
    }
  } catch (_) {}
  return true;
}

/// Under 13: the account just made is deleted at once (nothing is kept), then the "13 and older" screen.
Future<void> blockUnder13(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  try {
    await ref.read(apiProvider).deleteUnder13();
  } catch (_) {
    // Offline: the server also refuses the birth year, and the account is signed out below.
  }
  await signOutAndWipe(ref);
  router.go('/age-blocked');
}

/// The parent/guardian email step: inside setup (after "Tell us about you") and as its own screen for older
/// accounts. [onSent] runs after the email went out.
class GuardianStep extends ConsumerStatefulWidget {
  const GuardianStep({super.key, required this.onSent, this.footerButton = true});
  final VoidCallback onSent;

  /// Setup has its own footer; the stand-alone screen shows a button here.
  final bool footerButton;
  @override
  ConsumerState<GuardianStep> createState() => GuardianStepState();
}

class GuardianStepState extends ConsumerState<GuardianStep> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _err;
  static final _re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  bool get busy => _busy;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Sends the notice. Returns true when it went out.
  Future<bool> send() async {
    final e = _email.text.trim().toLowerCase();
    if (!_re.hasMatch(e)) {
      setState(() => _err = 'Enter a valid email, like mum@gmail.com');
      return false;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final msg = await ref.read(apiProvider).sendGuardianNotice(e);
      if (!mounted) return true;
      toast(context, msg, icon: PhosphorIcons.envelopeSimple(PhosphorIconsStyle.fill));
      widget.onSent();
      return true;
    } on ApiError catch (x) {
      if (mounted) setState(() => _err = x.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
      children: [
        Text('Your parent or guardian', style: context.ty.h1),
        const Gap(Space.s2),
        Text(
          'You are under 18, so we let a parent or guardian know you joined. We send them a short welcome email about SolutionTee CBT and how we keep your data safe.',
          style: context.ty.body.col(c.textMuted),
        ),
        const Gap(Space.s5),
        Field(
          label: "Parent's or guardian's email",
          hint: 'e.g. mum@gmail.com',
          icon: PhosphorIcons.envelopeSimple(),
          controller: _email,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          error: _err,
          onSubmitted: (_) => send(),
        ),
        const Gap(Space.s4),
        InfoBanner(
          icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
          child: const Text('They do not need to do anything. If they do not agree, the email has a button to turn your account off.'),
        ),
        if (widget.footerButton) ...[const Gap(Space.s6), Btn('Send the email', block: true, loading: _busy, onPressed: _busy ? null : send)],
      ],
    );
  }
}

/// Stand-alone parent step for accounts made before the age rules (route `/guardian`).
class GuardianScreen extends ConsumerWidget {
  const GuardianScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: TopBar(
          showBack: false,
          title: 'One more step',
          actions: [TextButton(onPressed: () => signOutAndWipe(ref), child: const Text('Log out'))],
        ),
        body: GuardianStep(onSent: () => context.go('/home')),
      ),
    );
  }
}

/// Under 13 (route `/age-blocked`, signed out). Neutral wording; nothing about the account was kept.
class AgeBlockedScreen extends StatelessWidget {
  const AgeBlockedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.s5),
              child: Column(
                children: [
                  StateBlock(
                    icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
                    tone: Tone.blue,
                    title: 'SolutionTee CBT is for students aged 13 and older',
                    text: 'We could not create your account, and we have not kept any of your details. Ask a parent, guardian or teacher about other ways to practise.',
                  ),
                  Btn('OK', block: true, onPressed: () => context.go('/welcome')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A parent or guardian turned this account off (route `/account-paused`).
class AccountPausedScreen extends ConsumerWidget {
  const AccountPausedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.s5),
              child: Column(
                children: [
                  StateBlock(
                    icon: PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
                    tone: Tone.red,
                    title: 'This account is turned off',
                    text: 'Your parent or guardian turned this account off. It will be deleted after 30 days. If this is a mistake, they can contact our support team.',
                  ),
                  Btn('Contact support', kind: BtnKind.outline, block: true, onPressed: () => context.push('/help')),
                  const Gap(Space.s2),
                  Btn('Log out', kind: BtnKind.ghost, block: true, onPressed: () => signOutAndWipe(ref)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
