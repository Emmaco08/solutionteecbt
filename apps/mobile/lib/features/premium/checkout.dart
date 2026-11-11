import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import 'pay_methods.dart';
import 'paystack_web.dart';
import 'paywall.dart';
import 'payments.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String payDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

enum _Stage { idle, opening, checking, waitingGoogle }

/// Plan checkout (prototype `checkout`). The amount shown comes from the server (`quote_price`); the app never
/// decides a price. Direct build: Paystack in an in-app browser tab, then "Checking payment". Play build: Google's sheet.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.planCode, this.provider});
  final String planCode;

  /// For tests: a payment provider to use instead of the build's own.
  final PaymentProvider? provider;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> with WidgetsBindingObserver {
  Quote? _quote;
  Object? _loadError;
  bool _codeOpen = false, _applying = false;
  String? _codeErr, _payErr;
  final _codeCtl = TextEditingController();
  _Stage _stage = _Stage.idle;
  String? _reference;
  PayMethod _method = PayMethod.card;
  String _bank = '737';
  Timer? _poll;
  int _polls = 0;

  PaymentProvider get _pay => widget.provider ?? ref.read(paymentProvider(usesPaystackNow(ref)));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _load({String? code}) async {
    try {
      final q = await ref.read(codeRepoProvider).quote(widget.planCode, code: code);
      if (mounted) setState(() => (_quote = q, _loadError = null));
    } on PayFailed catch (e) {
      if (code != null) rethrow;
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  // Coming back from the Paystack tab: check at once, then every 5 s for 2 minutes (bank transfers can take a moment).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _stage == _Stage.checking) _startPolling();
    if (s == AppLifecycleState.paused) _poll?.cancel();
  }

  void _startPolling() {
    _poll?.cancel();
    _polls = 0;
    _checkNow(quiet: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (t) {
      if (++_polls >= 24) t.cancel();
      _checkNow(quiet: true);
    });
  }

  bool _checking = false, _cancelling = false;

  /// "I did not pay": cancel on the server (it asks Paystack first, so a real payment still counts), D-095.
  Future<void> _cancelWaiting() async {
    final r = _reference, p = _pay;
    if (r == null || p is! PaystackProvider) return _handle(const PayCancelled());
    _poll?.cancel();
    setState(() => _cancelling = true);
    final res = await p.cancel(r, reason: 'tapped I did not pay');
    if (!mounted) return;
    setState(() => _cancelling = false);
    _handle(res);
  }

  Future<void> _checkNow({bool quiet = false}) async {
    final r = _reference;
    if (r == null || _checking || !mounted) return;
    setState(() => _checking = true);
    final res = await _pay.check(r);
    if (!mounted) return;
    setState(() => _checking = false);
    _handle(res, tapped: !quiet);
  }

  void _handle(PayResult r, {bool tapped = false}) {
    final plan = _plan;
    switch (r) {
      case PaySuccess(:final expiresAt):
        _poll?.cancel();
        refreshPlan(ref);
        context.go(
          '/pay-success',
          extra: {
            'plan': plan['name'],
            'expires_at': expiresAt,
            if ((_quote?.discountKobo ?? 0) > 0) 'code': _quote?.code,
            if ((_quote?.discountKobo ?? 0) > 0) 'saved': _quote?.discountKobo,
          },
        );
      case PayPending(:final reference):
        setState(() {
          _reference = reference ?? _reference;
          _stage = reference == null && !usesPaystackNow(ref) ? _Stage.waitingGoogle : _Stage.checking;
        });
        if (tapped && _stage == _Stage.checking) {
          toast(context, 'Not confirmed yet. If you have paid, give it a minute.', icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill));
        }
      case PayOffline():
        // Bank transfer / USSD: our own screen shows where to pay and checks by itself.
        setState(() => (_reference = r.reference, _stage = _Stage.checking));
        final p = _pay;
        if (p is! PaystackProvider) return;
        showPayOffline(context, r, p, what: 'Premium · ${plan['name']}').then((res) {
          if (!mounted) return;
          if (res == null || res is PayPending) {
            _startPolling(); // "I have paid": keep checking here; "Check payment" stays available
          } else {
            _handle(res);
          }
        });
      case PayWeb():
        // OPay, PocketApp, Zap, bank apps: Paystack's web checkout inside our own screen.
        setState(() => (_reference = r.reference, _stage = _Stage.checking));
        final p = _pay;
        if (p is! PaystackProvider) return;
        showPaystackWeb(context, r, p, what: 'Premium · ${plan['name']}', via: _method.viaName).then((res) {
          if (!mounted) return;
          if (res == null || res is PayPending) {
            _startPolling(); // "I have paid" but not confirmed yet: keep checking here
          } else {
            _handle(res); // paid, failed, or left and cancelled (D-095)
          }
        });
      case PayCancelled():
        // Left or cancelled before paying: stop checking, nothing is waiting any more (D-095).
        final wasWaiting = _reference != null;
        _poll?.cancel();
        setState(() => (_stage = _Stage.idle, _reference = null));
        if (wasWaiting) toast(context, 'Payment cancelled. You were not charged.', icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill));
      case PayFailed(:final message, :final code):
        _poll?.cancel();
        setState(() {
          _payErr = message;
          if (code != 'review') _stage = _Stage.idle;
        });
    }
  }

  Map<String, dynamic> get _plan {
    final plans = ref.read(plansForSaleProvider).value ?? const [];
    return plans.where((p) => p['code'] == widget.planCode).firstOrNull ?? {'code': widget.planCode, 'name': 'Premium'};
  }

  Future<void> _applyCode() async {
    final code = _codeCtl.text.trim().toUpperCase();
    if (code.isEmpty) return setState(() => _codeErr = 'Type your code first.');
    setState(() => (_applying = true, _codeErr = null));
    try {
      await _load(code: code);
      HapticFeedback.lightImpact();
    } on PayFailed catch (e) {
      setState(() => _codeErr = e.message);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _go() async {
    setState(() => (_stage = _Stage.opening, _payErr = null));
    final plan = _plan;
    final p = _pay;
    if (p is PaystackProvider) p.dark = Theme.of(context).brightness == Brightness.dark;
    final r = await p.buy(plan, code: (_quote?.discountKobo ?? 0) > 0 ? _quote?.code : null, channel: payChannel(_method, _bank));
    if (!mounted) return;
    _handle(r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paystack = usesPaystack(ref);
    final plans = ref.watch(plansForSaleProvider);
    final playPrices = ref.watch(playPricesProvider).value ?? const {};
    final q = _quote;
    if (_loadError != null) {
      return Scaffold(
        appBar: const TopBar(title: 'Checkout'),
        body: StateView.error(_loadError!, onRetry: () => setState(() => (_loadError = null, _load()))),
      );
    }
    if (q == null || !plans.hasValue) {
      return const Scaffold(
        appBar: TopBar(title: 'Checkout'),
        body: Padding(
          padding: EdgeInsets.all(Space.s5),
          child: Column(
            children: [
              Skeleton(height: 180, radius: Radii.lg),
              Gap(Space.s4),
              Skeleton(height: 56, radius: Radii.lg),
              Gap(Space.s4),
              Skeleton(height: 150, radius: Radii.lg),
            ],
          ),
        ),
      );
    }
    final plan = _plan;
    final playPrice = playPrices['${plan['play_product_id'] ?? ''}'];
    final total = paystack ? naira(q.amountKobo) : (playPrice ?? naira(q.listKobo));
    final discounted = paystack && q.discountKobo > 0;
    final fee = paystack ? q.feeKobo : 0;
    final busy = _stage == _Stage.opening;
    final sample = '${plan['description'] ?? ''}'.startsWith('SAMPLE');

    return Scaffold(
      appBar: TopBar(title: 'Checkout', onBack: _stage == _Stage.checking ? () => context.pop() : null),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Plan', style: context.ty.sm.col(c.textMuted))),
                    if (sample) const Pill('SAMPLE', kind: BadgeKind.sample),
                  ],
                ),
                const Gap(Space.s2),
                Text('SolutionTee Premium', style: context.ty.h3),
                const Gap(Space.s3),
                _row(context, 'Plan', '${plan['name']}'),
                _row(context, 'Access', q.periodEnd == null ? planPeriod(plan) : 'Until ${payDate(q.periodEnd!)}'),
                if (discounted || fee > 0) _row(context, 'Price', naira(q.listKobo)),
                if (discounted) ...[
                  _row(
                    context,
                    '${q.code} · ${q.label ?? ''}',
                    '−${naira(q.discountKobo)}',
                    color: c.success,
                    icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill),
                  ),
                ],
                // The admin chose to add the payment processing fee (D-113): always shown before paying.
                if (fee > 0) _row(context, 'Payment processing fee', '+${naira(fee)}'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s3),
                  child: Divider(height: 1, color: c.border),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Total', style: context.ty.body.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (discounted) Text(naira(q.listKobo), style: context.ty.cap.col(c.textMuted).copyWith(decoration: TextDecoration.lineThrough)),
                        Text(total, style: context.ty.h2.tnum),
                      ],
                    ),
                  ],
                ),
                // Paystack adds its exact fee on its own page (D-132): said before paying, never a surprise.
                if (paystack && ref.watch(paySettingsProvider).paystackAddsFee)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s2),
                    child: Text('+ Paystack’s processing fee, shown on the next screen before you pay.', style: context.ty.cap.col(c.textMuted)),
                  ),
              ],
            ),
          ),
          if (_payErr != null) ...[const Gap(Space.s4), InfoBanner(kind: BannerKind.err, child: Text(_payErr!))],
          const Gap(Space.s4),
          if (paystack && _pay.takesCodes)
            _codeBox(context, q)
          else if (!paystack)
            _note(context, PhosphorIcons.ticket(), 'Have a Google Play promo code? Enter it on the Google Play payment screen.'),
          const Gap(Space.s4),
          if (_stage == _Stage.checking)
            _checkingCard(context)
          else if (_stage == _Stage.waitingGoogle)
            InfoBanner(
              kind: BannerKind.warn,
              icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill),
              child: const Text('Google is waiting for your payment to arrive. Premium turns on by itself when it does, even if you close the app.'),
            )
          else
            paystack ? _paystackMethods(context) : _playMethod(context),
        ],
      ),
      bottomNavigationBar: _stage == _Stage.checking || _stage == _Stage.waitingGoogle
          ? null
          : FooterCta(
              child: Btn(
                busy
                    ? (paystack
                          ? (_method == PayMethod.card
                                ? 'Opening the card form'
                                : _method.inPaystackScreen
                                ? 'Opening Paystack'
                                : 'Getting your payment details')
                          : 'Opening Google Play')
                    : (paystack ? 'Pay $total ${_method.withText}' : 'Pay $total'),
                block: true,
                loading: busy,
                onPressed: busy ? null : _go,
              ),
            ),
    );
  }

  Widget _row(BuildContext context, String k, String v, {Color? color, IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s2),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: color), const Gap(Space.s1)],
        Expanded(child: Text(k, style: context.ty.sm.col(color ?? context.c.textMuted))),
        Text(v, style: context.ty.sm.bold.tnum.col(color ?? context.c.text)),
      ],
    ),
  );

  Widget _note(BuildContext context, IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: context.c.textMuted),
      const Gap(Space.s2),
      Expanded(child: Text(text, style: context.ty.cap.col(context.c.textMuted))),
    ],
  );

  Widget _codeBox(BuildContext context, Quote q) {
    final c = context.c;
    if (q.discountKobo > 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s2, Space.s3),
        decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(
          children: [
            Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), color: c.onSuccessSoft),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${q.code} applied', style: context.ty.sm.bold.col(c.onSuccessSoft)),
                  Text('You save ${naira(q.discountKobo)} (${q.label ?? ''})', style: context.ty.cap.col(c.onSuccessSoft)),
                ],
              ),
            ),
            IconBtn(
              PhosphorIcons.x(),
              label: 'Remove code',
              color: c.onSuccessSoft,
              onPressed: _stage != _Stage.idle
                  ? null
                  : () {
                      _codeCtl.clear();
                      _load();
                    },
            ),
          ],
        ),
      ).animate(target: context.reduceMotion ? 0 : 1).scale(begin: const Offset(.96, .96), end: const Offset(1, 1), duration: Motion.fast);
    }
    if (!_codeOpen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Btn('Have a discount code?', kind: BtnKind.ghost, sm: true, leading: PhosphorIcons.ticket(), onPressed: () => setState(() => _codeOpen = true)),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Field(
            label: 'Discount code',
            controller: _codeCtl,
            hint: 'e.g. LOYOLA20',
            icon: PhosphorIcons.ticket(),
            caps: TextCapitalization.characters,
            maxLength: 24,
            mono: true,
            autofocus: true,
            error: _codeErr,
            action: TextInputAction.done,
            onSubmitted: (_) => _applyCode(),
            onChanged: (_) => _codeErr == null ? null : setState(() => _codeErr = null),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), _Upper()],
          ),
        ),
        const Gap(Space.s2),
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Btn('Apply', kind: BtnKind.tonal, loading: _applying, onPressed: _applying ? null : _applyCode),
        ),
      ],
    );
  }

  Widget _paystackMethods(BuildContext context) =>
      PayMethodPicker(method: _method, bank: _bank, enabled: _stage == _Stage.idle, onChanged: (m, b) => setState(() => (_method = m, _bank = b)));

  Widget _playMethod(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Payment', style: context.ty.label),
      const Gap(Space.s3),
      ListCard(
        children: [
          ListRow(
            icon: PhosphorIcons.googlePlayLogo(PhosphorIconsStyle.fill),
            title: 'Google Play',
            caption: 'Card, Google Pay or other Play methods',
            caret: false,
          ),
        ],
      ),
      const Gap(Space.s3),
      Text('You will confirm the payment in Google Play. We check it with Google before Premium turns on.', style: context.ty.cap.col(context.c.textMuted)),
    ],
  );

  Widget _checkingCard(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.secondary)),
              const Gap(Space.s3),
              Expanded(child: Text('Checking payment', style: context.ty.h3)),
            ],
          ),
          const Gap(Space.s3),
          Text(
            'Finish paying on the Paystack page, then come back here. We check with Paystack by itself. A bank transfer can take a minute or two.',
            style: context.ty.sm.col(c.textMuted),
          ),
          const Gap(Space.s4),
          Btn(
            'I have paid, check now',
            block: true,
            loading: _checking,
            leading: PhosphorIcons.arrowsClockwise(),
            onPressed: _checking ? null : () => _checkNow(),
          ),
          const Gap(Space.s1),
          TextButton.icon(
            key: const ValueKey('checking-cancel'),
            onPressed: _checking || _cancelling ? null : _cancelWaiting,
            style: TextButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(48)),
            icon: _cancelling
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.error))
                : Icon(PhosphorIcons.xCircle(), size: 18),
            label: Text('I did not pay · cancel', style: context.ty.sm.bold.col(c.error)),
          ),
          const Gap(Space.s2),
          Text(
            'Closed the page by mistake? Go back and tap Pay again. If money left your account, Premium turns on by itself once Paystack tells us; you are never charged twice for one checkout.',
            style: context.ty.cap.col(c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Upper extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) => n.copyWith(text: n.text.toUpperCase());
}

/// Payment success (prototype `pay-success`): confetti, the plan and its end date, the exam logos.
class PaySuccessScreen extends ConsumerWidget {
  const PaySuccessScreen({super.key, this.info = const {}});
  final Map<String, Object?> info;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rm = context.reduceMotion;
    final first = '${ref.watch(profileProvider).value?['full_name'] ?? ''}'.trim().split(' ').first;
    final ai = ref.watch(accessRulesProvider).value?['premium']?['ai'];
    final until = info['expires_at'] as DateTime?;
    final saved = (info['saved'] as num?)?.toInt() ?? 0;
    return Scaffold(
      body: Stack(
        children: [
          if (!rm) const IgnorePointer(child: Confetti(delay: Duration(milliseconds: 200))),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s6, vertical: Space.s8),
                      child: Column(
                        children: [
                          Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(color: c.successSoft, shape: BoxShape.circle),
                                child: Icon(PhosphorIcons.checkFat(PhosphorIconsStyle.fill), size: 52, color: c.success),
                              )
                              .animate(target: rm ? 0 : 1)
                              .scale(begin: const Offset(.6, .6), end: const Offset(1, 1), duration: Motion.slow, curve: Curves.easeOutBack),
                          const Gap(Space.s5),
                          Text('You are now Premium!', style: context.ty.h1, textAlign: TextAlign.center),
                          const Gap(Space.s3),
                          Text(
                            '${first.isEmpty ? 'Thank you' : 'Thank you, $first'}. Every year, every exam${ai is num ? ' and $ai AI prompts a day' : ''} are now open.',
                            style: context.ty.body.col(c.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(Space.s5),
                          AppCard(
                            child: Column(
                              children: [
                                _kv(context, 'Plan', '${info['plan'] ?? 'Premium'}'),
                                if (until != null) _kv(context, 'Active until', payDate(until)),
                                if (saved > 0) _kv(context, 'Code ${info['code'] ?? ''}', 'You saved ${naira(saved)}', color: c.success),
                              ],
                            ),
                          ),
                          const Gap(Space.s5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const ExamLogo('JAMB', size: LogoSize.sm),
                              const Gap(Space.s2),
                              const ExamLogo('WAEC', size: LogoSize.sm),
                              const Gap(Space.s2),
                              const ExamLogo('NECO', size: LogoSize.sm),
                              const Gap(Space.s2),
                              Pill('Unlocked', kind: BadgeKind.success, icon: PhosphorIcons.lockSimpleOpen(PhosphorIconsStyle.fill)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FooterCta(clean: true, child: Btn('Start practising', block: true, onPressed: () => context.go('/home'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s1),
    child: Row(
      children: [
        Expanded(child: Text(k, style: context.ty.sm.col(context.c.textMuted))),
        Text(v, style: context.ty.sm.bold.col(color ?? context.c.text)),
      ],
    ),
  );
}

/// "Redeem a code" sheet on Me (prototype `#redeem`): free Premium days from a school, a teacher or SolutionTee.
/// In the Google Play app (D-117) a discount code (% or ₦ off) can be used on the payment website when the admin offers it:
/// the code goes with the student to the website, already logged in, for [plan].
Future<void> showRedeemSheet(BuildContext context, {String? plan}) => showSheet<void>(context, builder: (_) => _RedeemSheet(plan: plan));

class _RedeemSheet extends ConsumerStatefulWidget {
  const _RedeemSheet({this.plan});
  final String? plan;
  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<_RedeemSheet> {
  final _ctl = TextEditingController();
  String? _err;
  bool _busy = false;
  (int, DateTime?)? _done;
  String? _discount; // a discount code that can be used on the payment website

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final code = _ctl.text.trim();
    if (code.isEmpty) return setState(() => _err = 'Type your code first.');
    setState(() => (_busy = true, _err = null));
    try {
      final r = await ref.read(codeRepoProvider).redeem(code);
      refreshPlan(ref);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _done = r);
    } on PayFailed catch (e) {
      if (!mounted) return;
      final playWeb = !usesPaystack(ref) && ref.read(paySettingsProvider).playWebsite;
      if (e.code == 'discount_code' && playWeb) {
        setState(() => _discount = code.toUpperCase());
      } else if (e.code == 'discount_code' && !usesPaystack(ref)) {
        setState(() => _err = 'This is a discount code. It cannot be used with Google Play payments.');
      } else {
        setState(() => _err = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = _done;
    if (done != null) {
      return Column(
        children: [
          Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: c.successSoft, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.gift(PhosphorIconsStyle.fill), size: 44, color: c.success),
              )
              .animate(target: context.reduceMotion ? 0 : 1)
              .scale(begin: const Offset(.6, .6), end: const Offset(1, 1), duration: Motion.slow, curve: Curves.easeOutBack),
          const Gap(Space.s4),
          Text('${done.$1} days of Premium added!', style: context.ty.h2, textAlign: TextAlign.center),
          if (done.$2 != null) ...[
            const Gap(Space.s2),
            Text('Everything is unlocked until ${payDate(done.$2!)}.', style: context.ty.body.col(c.textMuted), textAlign: TextAlign.center),
          ],
          const Gap(Space.s5),
          Btn('Start practising', block: true, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    final discount = _discount;
    if (discount != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(PhosphorIcons.ticket(PhosphorIconsStyle.fill), size: 44, color: c.success),
          const Gap(Space.s3),
          Text('$discount is a discount code', style: context.ty.h3, textAlign: TextAlign.center),
          const Gap(Space.s2),
          Text(
            'Use it on our payment website: card, bank transfer, USSD or OPay. You stay logged in, and Premium shows here as soon as you pay.',
            style: context.ty.sm.col(c.textMuted),
            textAlign: TextAlign.center,
          ),
          const Gap(Space.s5),
          Btn(
            'Pay on the website with $discount',
            kind: BtnKind.accent,
            block: true,
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              final ok = await openPayWebsite(ref, plan: widget.plan ?? 'three_months', code: discount);
              if (!mounted || !context.mounted) return;
              setState(() => _busy = false);
              if (ok) {
                Navigator.of(context).pop();
              } else {
                toast(context, 'Could not open the website. Please try again.');
              }
            },
          ),
          const Gap(Space.s2),
          Btn('Use another code', kind: BtnKind.ghost, block: true, onPressed: () => setState(() => _discount = null)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Redeem a code', style: context.ty.h3),
        const Gap(Space.s2),
        Text('Got a code from your school, a teacher or SolutionTee? Enter it here.', style: context.ty.sm.col(c.textMuted)),
        const Gap(Space.s4),
        Field(
          label: 'Code',
          controller: _ctl,
          hint: 'e.g. FREEWEEK',
          icon: PhosphorIcons.ticket(),
          caps: TextCapitalization.characters,
          maxLength: 24,
          mono: true,
          autofocus: true,
          error: _err,
          action: TextInputAction.done,
          onSubmitted: (_) => _go(),
          onChanged: (_) => _err == null ? null : setState(() => _err = null),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), _Upper()],
        ),
        const Gap(Space.s4),
        Btn('Redeem', block: true, loading: _busy, onPressed: _busy ? null : _go),
      ],
    );
  }
}
