import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../tutor/tutor.dart';
import 'payments.dart';

/// Back from the payment website (D-116): the browser opens solutiontee://app/paid?ref=st_…&plan=…
/// The app asks the server about that payment (the server asks Paystack), then shows the normal "Premium is on" screen,
/// or the tutor screen "Your tutor plan is on!" for a tutor plan (D-153: a tutor payment is never called Premium).
/// Nothing is trusted from the link itself: only the server's answer for this signed-in student counts.
class PaidReturnScreen extends ConsumerStatefulWidget {
  const PaidReturnScreen({super.key, required this.reference, this.plan, this.kind});
  final String reference;
  final String? plan;

  /// "tutor" from the website's link back; the server's own answer wins when it gives one.
  final String? kind;
  @override
  ConsumerState<PaidReturnScreen> createState() => _PaidReturnScreenState();
}

class _PaidReturnScreenState extends ConsumerState<PaidReturnScreen> {
  String? _err;
  int _tries = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!RegExp(r'^st_[0-9a-f]{20}$').hasMatch(widget.reference)) {
      setState(() => _err = 'This link is not a SolutionTee payment.');
      return;
    }
    final p = ref.read(paymentProvider(true));
    final r = await p.check(widget.reference);
    if (!mounted) return;
    switch (r) {
      case PaySuccess(:final expiresAt, :final kind):
        if ((kind ?? widget.kind) == 'tutor') {
          ref.invalidate(tutorProvider);
          context.go('/tutor');
          context.push('/tutor/paid');
          return;
        }
        refreshPlan(ref);
        context.go('/pay-success', extra: {'plan': widget.plan ?? 'Premium', 'expires_at': expiresAt});
      case PayFailed(:final message, :final code) when code == 'failed' || code == 'review' || code == 'refunded':
        setState(() => _err = message);
      case PayCancelled():
        setState(() => _err = 'This payment was cancelled. You were not charged.');
      default:
        // Still on its way (bank transfer can take a few minutes), or a slow connection: ask again for about 2 minutes.
        // A login problem is never shown here: the server is asked by the payment reference instead (D-129).
        if (++_tries < 24) {
          _t = Timer(const Duration(seconds: 5), _check);
        } else {
          setState(() => _err = 'We have not received the payment yet. Premium turns on by itself as soon as it arrives.');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: TopBar(title: 'Payment', onBack: () => context.go('/home')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.s5),
          child: _err == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 4)),
                    const Gap(Space.s5),
                    Text('Confirming your payment…', style: context.ty.h3, textAlign: TextAlign.center),
                    const Gap(Space.s2),
                    Text(
                      _tries < 3 ? 'This takes a few seconds.' : 'Still checking with Paystack. Bank transfers can take a few minutes.',
                      style: context.ty.sm.col(c.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : StateBlock(
                  icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill),
                  tone: Tone.blue,
                  title: 'Not confirmed yet',
                  text: _err,
                  action: Btn('Back to home', block: true, onPressed: () => context.go('/home')),
                ),
        ),
      ),
    );
  }
}
