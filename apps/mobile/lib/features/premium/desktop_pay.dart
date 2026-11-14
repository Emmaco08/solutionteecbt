import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'pay_ui.dart';
import 'payments.dart';

/// Desktop checkout (D-166): Windows has no in-app WebView for Paystack, so Paystack's page opens in the student's own
/// browser and this screen waits, checking the server every 3 seconds (the same check the phone uses). It closes by
/// itself as soon as the payment is confirmed. Leaving asks first and cancels on the server (D-095).
Future<PayResult?> showDesktopPay(BuildContext context, PayWeb w, PaystackProvider pay, {required String what, String? via}) =>
    Navigator.of(context, rootNavigator: true).push<PayResult>(
      MaterialPageRoute(
        builder: (_) => DesktopPayScreen(w: w, pay: pay, what: what, via: via),
      ),
    );

class DesktopPayScreen extends StatefulWidget {
  const DesktopPayScreen({super.key, required this.w, required this.pay, required this.what, this.via, this.openBrowser});
  final PayWeb w;
  final PaystackProvider pay;
  final String what;
  final String? via;

  /// For tests: replaces opening the real browser.
  final Future<bool> Function(Uri)? openBrowser;

  @override
  State<DesktopPayScreen> createState() => _DesktopPayScreenState();
}

class _DesktopPayScreenState extends State<DesktopPayScreen> {
  Timer? _poll;
  bool _checking = false, _done = false, _leaving = false, _opened = false;
  int _checks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    final open = widget.openBrowser ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    final ok = await open(widget.w.url).catchError((_) => false);
    if (mounted) setState(() => _opened = ok);
    if (!ok && mounted) {
      toast(context, 'Could not open your browser. Use "Open the payment page" below.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _check({bool tapped = false}) async {
    if (_checking || _done || !mounted) return;
    setState(() => _checking = true);
    final r = await widget.pay.check(widget.w.reference);
    _checks++;
    if (!mounted || _done) return;
    setState(() => _checking = false);
    if (r is PaySuccess || (r is PayFailed && r.code == 'review')) {
      _done = true;
      Navigator.of(context).pop(r);
    } else if (tapped) {
      toast(context, 'Not confirmed yet. If you have paid, give it a minute.', icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _leave() async {
    if (_done || _leaving) return;
    final choice = await confirmLeavePayment(context, via: widget.via, what: widget.what);
    if (!mounted || _done) return;
    switch (choice) {
      case LeaveChoice.stay:
        return;
      case LeaveChoice.paid:
        await _check(tapped: true);
        if (!_done && mounted) {
          _done = true;
          Navigator.of(context).pop(PayPending(widget.w.reference));
        }
      case LeaveChoice.leave:
        setState(() => _leaving = true);
        final r = await widget.pay
            .cancel(widget.w.reference, reason: 'left the desktop checkout')
            .timeout(const Duration(seconds: 10), onTimeout: () => const PayCancelled());
        if (!mounted || _done) return;
        _done = true;
        Navigator.of(context).pop(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: TopBar(title: widget.via == null ? 'Pay' : 'Pay with ${widget.via}', onBack: _leave),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AppCard(
                padding: const EdgeInsets.all(Space.s8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                      child: Icon(PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.fill), size: 48, color: c.onAccentSoft),
                    ).animate(onPlay: (a) => rm ? null : a.repeat(reverse: true)).scaleXY(begin: 1, end: 1.06, duration: 1200.ms, curve: Curves.easeInOut),
                    const Gap(Space.s5),
                    Text('Finish paying in your browser', style: context.ty.h2, textAlign: TextAlign.center),
                    const Gap(Space.s2),
                    Text(widget.what, style: context.ty.body.col(c.textMuted), textAlign: TextAlign.center),
                    const Gap(Space.s6),
                    _Step(
                      n: 1,
                      text: _opened
                          ? 'Paystack\'s secure page is open in your browser. Pay there with card, bank transfer, USSD or your bank app.'
                          : 'Opening Paystack\'s secure page in your browser…',
                    ),
                    const _Step(n: 2, text: 'Come back to this window. We confirm your payment by ourselves and this page closes.'),
                    const Gap(Space.s5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.text)),
                          const Gap(Space.s3),
                          Flexible(
                            child: Text(
                              _checks == 0 ? 'Waiting for Paystack…' : 'Waiting for your payment · checked $_checks ${_checks == 1 ? 'time' : 'times'}',
                              style: context.ty.sm.col(c.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(Space.s6),
                    Btn(
                      'I have paid · check now',
                      block: true,
                      loading: _checking,
                      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      onPressed: () => _check(tapped: true),
                    ),
                    const Gap(Space.s3),
                    Btn('Open the payment page again', block: true, kind: BtnKind.outline, icon: PhosphorIcons.arrowSquareOut(), onPressed: _open),
                    const Gap(Space.s3),
                    Btn('Cancel payment', block: true, kind: BtnKind.ghost, loading: _leaving, onPressed: _leave),
                    const Gap(Space.s4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 16, color: c.textSubtle),
                        const Gap(Space.s2),
                        Text('Secured by Paystack · we never see your card', style: context.ty.cap.col(c.textSubtle)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Palette.navy900, shape: BoxShape.circle),
            child: Text('$n', style: context.ty.sm.bold.col(Colors.white)),
          ),
          const Gap(Space.s3),
          Expanded(child: Text(text, style: context.ty.body.col(c.text))),
        ],
      ),
    );
  }
}
