import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'paywall.dart';
import 'payments.dart';

/// "card", "transfer" or "ussd:737": what [PaystackProvider.buy] takes as its channel.
String payChannel(PayMethod m, String bank) => switch (m) {
  PayMethod.card => 'card',
  PayMethod.transfer => 'transfer',
  PayMethod.ussd => 'ussd:$bank',
  // Only inside Paystack's own screen (Paystack's API does not offer them to apps directly): it opens inside the app.
  PayMethod.opay || PayMethod.pocketapp || PayMethod.zap || PayMethod.bankApp => 'page',
};

/// Choose how to pay (D-089, D-092): card (Paystack's secure sheet in the app), bank transfer or USSD (our own screens),
/// or an app (OPay, Zap, bank apps), which Paystack only offers inside its own screen (it opens in the app).
class PayMethodPicker extends StatelessWidget {
  const PayMethodPicker({super.key, required this.method, required this.bank, required this.onChanged, this.enabled = true});
  final PayMethod method;
  final String bank;
  final void Function(PayMethod method, String bank) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    var n = 0;
    Widget option(PayMethod m, IconData icon, String title, String caption) {
      final on = m == method;
      final i = n++;
      final card = Semantics(
        selected: on,
        button: true,
        label: title,
        child: AnimatedContainer(
          duration: Motion.fast,
          margin: const EdgeInsets.only(bottom: Space.s2),
          decoration: BoxDecoration(
            color: on ? c.primarySoft : c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: on ? c.secondary : c.border, width: on ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: enabled ? () => onChanged(m, bank) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
              child: Row(
                children: [
                  PayBrandTile(
                    method: m,
                    size: 40,
                    fallback: IconTile(icon, tone: on ? Tone.blue : Tone.navy, size: 40, radius: 12, iconSize: 20),
                  ),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.ty.sm.bold),
                        Text(caption, style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    child: Icon(
                      on ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                      key: ValueKey(on),
                      size: 22,
                      color: on ? c.secondary : c.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return rm ? card : card.animate().fadeIn(delay: (40 * i).ms, duration: 260.ms).slideX(begin: .06, end: 0, curve: Curves.easeOutCubic);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How do you want to pay?', style: context.ty.label),
        const Gap(Space.s3),
        option(PayMethod.card, PhosphorIcons.creditCard(PhosphorIconsStyle.fill), 'Card', 'Visa, Mastercard, Verve · opens a secure card form'),
        option(PayMethod.transfer, PhosphorIcons.bank(PhosphorIconsStyle.fill), 'Bank transfer', 'Send from any Nigerian bank app'),
        option(PayMethod.ussd, PhosphorIcons.hash(PhosphorIconsStyle.fill), 'USSD', 'Dial a code. Works on any phone, no data'),
        const Gap(Space.s1),
        Text('Pay with an app', style: context.ty.cap.bold.col(c.textMuted)),
        const Gap(Space.s2),
        option(PayMethod.opay, PhosphorIcons.wallet(PhosphorIconsStyle.fill), 'OPay', 'Approve in your OPay app'),
        // PocketApp is hidden: Paystack does not offer it on this account's checkout (owner, 2026-11-04). Add the line back when it does.
        option(PayMethod.zap, PhosphorIcons.lightning(PhosphorIconsStyle.fill), 'Zap', 'Pay with the Zap app'),
        option(PayMethod.bankApp, PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill), 'Bank app', 'Kuda, PalmPay and other bank apps'),
        if (method.inPaystackScreen)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: InfoBanner(
              icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
              child: Text(
                'Opens straight on ${switch (method) {
                  PayMethod.opay => 'OPay',
                  PayMethod.pocketapp => 'PocketApp',
                  PayMethod.zap => 'Zap',
                  _ => 'your bank app',
                }}, on Paystack\'s secure page inside the app. We add your Premium or XP as soon as it is paid.',
              ),
            ),
          ),
        if (method == PayMethod.ussd) ...[
          const Gap(Space.s1),
          Text('Your bank', style: context.ty.cap.bold.col(c.textMuted)),
          const Gap(Space.s2),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final e in ussdBanks.entries)
                ChoiceChip(label: Text('${e.value} *${e.key}#'), selected: bank == e.key, onSelected: enabled ? (_) => onChanged(PayMethod.ussd, e.key) : null),
            ],
          ).animate().fadeIn(duration: context.reduceMotion ? 1.ms : 200.ms),
        ],
        const Gap(Space.s2),
        Row(
          children: [
            Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 14, color: c.textMuted),
            const Gap(Space.s1),
            Expanded(
              child: Text(
                'Secured by Paystack. We never see your card details. Premium or XP is added after we confirm the payment.',
                style: context.ty.cap.col(c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Our own "pay by bank transfer / USSD" screen. Checks the payment every 5 seconds while open and closes itself
/// with the result when it is confirmed. Closing it early returns null (the payment can still be checked later).
Future<PayResult?> showPayOffline(BuildContext context, PayOffline o, PaystackProvider pay, {required String what}) =>
    Navigator.of(context, rootNavigator: true).push<PayResult>(
      MaterialPageRoute(
        builder: (_) => PayOfflineScreen(o: o, pay: pay, what: what),
      ),
    );

class PayOfflineScreen extends StatefulWidget {
  const PayOfflineScreen({super.key, required this.o, required this.pay, required this.what});
  final PayOffline o;
  final PaystackProvider pay;

  /// What is being bought, e.g. "Premium · 3 Months" or "550 XP".
  final String what;
  @override
  State<PayOfflineScreen> createState() => _PayOfflineScreenState();
}

class _PayOfflineScreenState extends State<PayOfflineScreen> with WidgetsBindingObserver {
  Timer? _poll, _tick;
  bool _sent = false, _checking = false;
  String? _error;

  DateTime? get _expires => DateTime.tryParse('${widget.o.transfer?['expires_at'] ?? ''}')?.toLocal();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // Back from the bank app or the dialler: check at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    final r = await widget.pay.check(widget.o.reference);
    _checking = false;
    if (!mounted) return;
    switch (r) {
      case PaySuccess():
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(r);
      case PayFailed(:final code) when code == 'review':
        Navigator.of(context).pop(r);
      case PayFailed(:final message):
        // A transfer that has not arrived is "pending", not failed; a real failure ends here.
        setState(() => _error = message);
      default:
        break;
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    toast(context, '$what copied', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.o.transfer, u = widget.o.ussd;
    final amount = naira(widget.o.amountKobo);
    final exp = _expires;
    final left = exp?.difference(DateTime.now());
    final expired = left != null && left.isNegative;
    final rm = context.reduceMotion;

    Widget copyRow(String label, String value, {bool big = false, String? copyAs}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.ty.cap.col(c.textMuted)),
                Text(value, style: (big ? context.ty.h2 : context.ty.body.bold).tnum.copyWith(letterSpacing: big ? 1.5 : 0)),
              ],
            ),
          ),
          if (copyAs != null)
            Btn(
              'Copy',
              kind: BtnKind.tonal,
              sm: true,
              leading: PhosphorIcons.copy(),
              onPressed: () => _copy(value.replaceAll(RegExp(r'[^0-9*#]'), ''), copyAs),
            ),
        ],
      ),
    );

    final body = <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.what, style: context.ty.sm.col(c.textMuted)),
            const Gap(Space.s1),
            Row(
              children: [
                Expanded(child: Text(t != null ? 'Transfer exactly' : 'Amount', style: context.ty.body.bold)),
                Text(amount, style: context.ty.h2.tnum),
              ],
            ),
          ],
        ),
      ),
      if (t != null) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copyRow('Bank', '${t['bank']}'),
              Divider(height: 1, color: c.border),
              copyRow('Account number', '${t['account_number']}', big: true, copyAs: 'Account number'),
              Divider(height: 1, color: c.border),
              copyRow('Account name', '${t['account_name']}'),
              Divider(height: 1, color: c.border),
              copyRow('Amount', amount, copyAs: 'Amount'),
            ],
          ),
        ),
        if (exp != null)
          InfoBanner(
            kind: expired ? BannerKind.err : BannerKind.warn,
            icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
            child: Text(
              expired
                  ? 'This account has expired. Go back and start again. If you already sent money, it will be returned to you or added once it arrives.'
                  : 'Use this account once, within ${left!.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}. Send the exact amount from your bank app.',
            ),
          ),
      ],
      if (u != null) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Dial this code with the phone number your ${u['bank']} account uses', style: context.ty.sm.col(c.textMuted)),
              const Gap(Space.s3),
              Center(child: SelectableText('${u['code']}', style: context.ty.display.tnum.copyWith(fontSize: 30, letterSpacing: 1))),
              const Gap(Space.s3),
              Row(
                children: [
                  Expanded(
                    child: Btn(
                      'Dial now',
                      kind: BtnKind.accent,
                      leading: PhosphorIcons.phoneCall(PhosphorIconsStyle.fill),
                      onPressed: () => launchUrl(Uri.parse('tel:${Uri.encodeComponent('${u['code']}')}')),
                    ),
                  ),
                  const Gap(Space.s2),
                  Btn('Copy', kind: BtnKind.tonal, leading: PhosphorIcons.copy(), onPressed: () => _copy('${u['code']}', 'Code')),
                ],
              ),
              const Gap(Space.s3),
              Text(
                'Follow the steps your bank shows and enter your PIN on the bank\'s screen. Never share your PIN with anyone.',
                style: context.ty.cap.col(c.textMuted),
              ),
            ],
          ),
        ),
      ],
      if (_error != null) InfoBanner(kind: BannerKind.err, child: Text(_error!)),
      // Waiting card
      AppCard(
        child: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.secondary)),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sent ? 'Waiting for your bank…' : 'Waiting for your payment', style: context.ty.sm.bold),
                  Text(
                    _sent
                        ? 'Most payments arrive in under a minute. This page updates by itself.'
                        : 'This page updates by itself as soon as the money arrives. You can leave and come back.',
                    style: context.ty.cap.col(c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: TopBar(title: t != null ? 'Pay by bank transfer' : 'Pay with USSD', onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
        children: [
          for (var i = 0; i < body.length; i++) ...[
            if (i > 0) const Gap(Space.s3),
            rm ? body[i] : body[i].animate(delay: (60 * i).ms).fadeIn(duration: 250.ms).slideY(begin: .05, end: 0, curve: Curves.easeOutCubic),
          ],
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Btn(
          _sent ? 'Check now' : (t != null ? 'I have sent the money' : 'I have finished dialling'),
          block: true,
          loading: _checking && _sent,
          onPressed: () {
            setState(() => _sent = true);
            _check();
          },
        ),
      ),
    );
  }
}

/// The real OPay / Zap marks (assets/third_party, from the companies' own sources) for their payment options;
/// other ways to pay use [fallback] (our icon tile).
class PayBrandTile extends StatelessWidget {
  const PayBrandTile({super.key, required this.method, this.size = 40, required this.fallback});
  final PayMethod method;
  final double size;
  final Widget fallback;
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * .3);
    switch (method) {
      case PayMethod.opay:
        return Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: r,
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: SvgPicture.asset('assets/third_party/opay_mark.svg', semanticsLabel: 'OPay'),
        );
      case PayMethod.zap:
        return ClipRRect(
          borderRadius: r,
          child: Image.asset('assets/third_party/zap_icon.png', width: size, height: size, semanticLabel: 'Zap', filterQuality: FilterQuality.medium),
        );
      default:
        return fallback;
    }
  }
}
