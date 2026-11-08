import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ads.dart';
import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/pay_methods.dart';
import '../premium/paystack_web.dart';
import '../premium/payments.dart';

/// XP — the app's game coin (D-081, plan `docs/plans/xp-streaks.md`). Earned by practising, spent on challenge
/// entries, Premium and streak freezes. The server gives and takes every XP; the phone only shows it.

final myXpProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  if (currentSession(ref) == null) return const {'enabled': false};
  final j = await ref.read(supabaseProvider).rpc('my_xp').timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(j as Map);
});

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String xpText(num n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

const _reasons = {
  'daily_claim': 'Daily claim',
  'test': 'Test finished',
  'mock': 'Mock finished',
  'qotd': 'Question of the day',
  'challenge': 'Challenge finished',
  'referral': 'Friend joined',
  'admin': 'From SolutionTee',
  'pack': 'Bought XP',
  'premium': 'Premium with XP',
  'entry': 'Challenge entry',
  'streak': 'Streak bonus',
  'freeze': 'Streak freeze',
};

/// The gold XP coin.
class XpCoin extends StatelessWidget {
  const XpCoin({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Color(0xFFFFD66B), Palette.gold500], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Text(
      'XP',
      style: TextStyle(fontSize: size * .38, fontWeight: FontWeight.w800, color: Palette.navy900, height: 1),
    ),
  );
}

/// Home header: the XP balance (tap → My XP). Hidden when XP is off.
class XpChip extends ConsumerWidget {
  const XpChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(myXpProvider).value;
    if (d == null || d['enabled'] != true) return const SizedBox.shrink();
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: Space.s2),
      child: Semantics(
        button: true,
        label: '${d['balance']} XP',
        child: GestureDetector(
          onTap: () => openRoute(context, '/me/xp'),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(99)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const XpCoin(),
                const SizedBox(width: 5),
                Text(xpText(_i(d['balance'])), style: context.ty.label.bold.tnum.col(c.onAccentSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Claims today's XP (once a Lagos day). Returns the XP given (0 = already claimed or XP off).
Future<int> claimDailyXp(WidgetRef ref) async {
  final j = Map<String, dynamic>.from(await ref.read(supabaseProvider).rpc('xp_claim_daily').timeout(const Duration(seconds: 15)) as Map);
  ref.invalidate(myXpProvider);
  return _i(j['given']);
}

/// Home: "Claim +10 XP" until today's XP is claimed.
class DailyClaimCard extends ConsumerStatefulWidget {
  const DailyClaimCard({super.key});
  @override
  ConsumerState<DailyClaimCard> createState() => _DailyClaimCardState();
}

class _DailyClaimCardState extends ConsumerState<DailyClaimCard> {
  bool _busy = false;
  int? _got;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final g = await claimDailyXp(ref);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _got = g);
    } catch (_) {
      if (mounted) toast(context, 'Could not claim. Check your internet and try again.', icon: PhosphorIcons.wifiSlash());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(myXpProvider).value;
    if (_got != null) {
      return AppCard(
        child: Row(
          children: [
            const XpCoin(size: 36),
            const Gap(Space.s3),
            Expanded(child: Text(_got! > 0 ? '+$_got XP claimed. See you tomorrow!' : 'Already claimed today.', style: context.ty.sm.bold)),
          ],
        ),
      ).animate().fadeIn(duration: Motion.base).scale(begin: const Offset(.96, .96), end: const Offset(1, 1), curve: Motion.out);
    }
    if (d == null || d['enabled'] != true || d['claimed_today'] == true) return const SizedBox.shrink();
    final c = context.c;
    return Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              const XpCoin(size: 40)
                  .animate(onPlay: (a) => context.reduceMotion ? null : a.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 900.ms, curve: Curves.easeInOut),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your daily XP is ready', style: context.ty.sm.bold.col(Colors.white)),
                    Text('Claim it every day you open the app.', style: context.ty.cap.col(const Color(0xFFDCE4F2))),
                  ],
                ),
              ),
              Btn('Claim +${_i(d['daily_claim'])}', kind: BtnKind.accent, sm: true, loading: _busy, onPressed: _busy ? null : _claim),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: Motion.base)
        .slideY(begin: .1, end: 0, curve: Motion.out, duration: Motion.base)
        .then()
        .shimmer(duration: context.reduceMotion ? 1.ms : 1400.ms, color: c.accent.withValues(alpha: .25));
  }
}

/// Me → My XP: balance, today's progress, ways to earn, history.
class XpWalletScreen extends ConsumerWidget {
  const XpWalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(myXpProvider);
    return Scaffold(
      appBar: const TopBar(title: 'My XP'),
      body: asyncView(
        v,
        (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myXpProvider),
          child: _Wallet(d: d),
        ),
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: const [
            Skeleton(height: 170, radius: Radii.lg),
            Gap(Space.s3),
            Skeleton(height: 220, radius: Radii.lg),
          ],
        ),
        onRetry: () => ref.invalidate(myXpProvider),
      ),
    );
  }
}

class _Wallet extends StatelessWidget {
  const _Wallet({required this.d});
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (d['enabled'] != true) {
      return ListView(
        children: [
          const Gap(Space.s8),
          StateBlock(icon: PhosphorIcons.coins(PhosphorIconsStyle.fill), tone: Tone.gold, title: 'XP is paused', text: 'Your XP is safe. Check back soon.'),
        ],
      );
    }
    final rules = d['rules'] is Map ? Map<String, dynamic>.from(d['rules'] as Map) : const <String, dynamic>{};
    final today = _i(d['today']), cap = _i(d['daily_cap']);
    final history = rows(d['history']);
    final ways = <(IconData, String, String)>[
      (PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill), 'Open the app and claim', '+${_i(rules['daily_claim'])} XP a day'),
      (PhosphorIcons.exam(PhosphorIconsStyle.fill), 'Finish a test', '+${_i(rules['test'])} XP, more for a good score'),
      (PhosphorIcons.trophy(PhosphorIconsStyle.fill), 'Finish a full mock', '+${_i(rules['mock'])} XP'),
      (PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), 'Question of the day', '+${_i(rules['qotd']) + _i(rules['qotd_right'])} XP when right'),
      (PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill), 'Finish a challenge', '+${_i(rules['challenge_finish'])} XP'),
      (PhosphorIcons.gift(PhosphorIconsStyle.fill), 'A friend joins with your code', '+${_i(rules['referral'])} XP'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
      children: [
        Container(
          padding: const EdgeInsets.all(Space.s5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            children: [
              const XpCoin(size: 56).animate().scale(begin: const Offset(.6, .6), end: const Offset(1, 1), duration: Motion.slow, curve: Curves.elasticOut),
              const Gap(Space.s3),
              Text(xpText(_i(d['balance'])), style: context.ty.display.tnum.col(Colors.white)),
              Text('XP', style: context.ty.sm.bold.col(Palette.gold500)),
              if (_i(d['bought']) > 0) ...[
                const Gap(Space.s1),
                Text('${xpText(_i(d['bought']))} bought · ${xpText(_i(d['earned']))} earned', style: context.ty.cap.col(const Color(0xFFDCE4F2))),
              ],
              const Gap(Space.s4),
              Row(
                children: [
                  Expanded(child: Text('Earned today', style: context.ty.cap.col(const Color(0xFFDCE4F2)))),
                  Text('${xpText(today)} / ${xpText(cap)}', style: context.ty.cap.bold.tnum.col(Colors.white)),
                ],
              ),
              const Gap(Space.s1),
              ProgressBar(cap == 0 ? 0 : today / cap, color: Palette.gold500, track: Colors.white.withValues(alpha: .15)),
            ],
          ),
        ),
        const Gap(Space.s3),
        const DailyClaimCard(),
        const WatchForXpCard(),
        const AdBanner(screen: 'xp'),
        const Gap(Space.s3),
        const SectTitle('Ways to earn XP'),
        ListCard(
          children: [
            for (final (ic, t, x) in ways)
              Padding(
                padding: const EdgeInsets.all(Space.s3),
                child: Row(
                  children: [
                    IconTile(ic, tone: Tone.gold, size: 36, radius: 10, iconSize: 18),
                    const Gap(Space.s3),
                    Expanded(child: Text(t, style: context.ty.sm.bold)),
                    Text(x, style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
          ],
        ),
        const Gap(Space.s2),
        if (rows(d['premium_options']).isNotEmpty) ...[
          const SectTitle('Get Premium with XP'),
          _PremiumWithXp(options: rows(d['premium_options']), balance: _i(d['balance'])),
        ],
        // XP cannot be bought any more (D-110): it is earned. The server refuses packs while xp.buy_on is off.
        if (d['buy_on'] == true && rows(d['packs']).isNotEmpty && store != Store.play) ...[const SectTitle('Buy XP'), _BuyXp(packs: rows(d['packs']))],
        const Gap(Space.s2),
        Text('You can also spend XP on challenge entries and streak freezes.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
        const Gap(Space.s3),
        const SectTitle('History'),
        if (history.isEmpty)
          Text('No XP yet. Claim your daily XP or finish a test.', style: context.ty.sm.col(c.textMuted))
        else
          ListCard(
            children: [
              for (final h in history)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_reasons[h['reason']] ?? '${h['reason']}', style: context.ty.sm.bold),
                            if ((h['note'] ?? '').toString().isNotEmpty) Text('${h['note']}', style: context.ty.cap.col(c.textMuted)),
                            Text(_when('${h['at']}'), style: context.ty.cap.col(c.textSubtle)),
                          ],
                        ),
                      ),
                      Text(
                        '${_i(h['amount']) > 0 ? '+' : ''}${xpText(_i(h['amount']))}',
                        style: context.ty.body.bold.tnum.col(_i(h['amount']) > 0 ? c.success : c.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _when(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${m[t.month - 1]}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// Used by Supabase errors in this file.
String xpError(Object e) => e is PostgrestException && e.message.isNotEmpty ? e.message : 'Something went wrong. Check your internet and try again.';

/// Premium paid with XP (D-083): the admin's XP price per plan; the server takes the XP and gives Premium.
class _PremiumWithXp extends ConsumerStatefulWidget {
  const _PremiumWithXp({required this.options, required this.balance});
  final List<Map<String, dynamic>> options;
  final int balance;
  @override
  ConsumerState<_PremiumWithXp> createState() => _PremiumWithXpState();
}

class _PremiumWithXpState extends ConsumerState<_PremiumWithXp> {
  String? _busy;

  Future<void> _buy(Map<String, dynamic> o) async {
    final ok = await showAppDialog<bool>(
      context,
      title: 'Get ${o['name']} for ${xpText(_i(o['xp']))} XP?',
      body: 'Premium starts now, or when your current Premium ends.',
      icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
      tone: Tone.gold,
      actions: [
        Builder(
          builder: (ctx) => Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx, false)),
        ),
        Builder(
          builder: (ctx) => Btn('Pay ${xpText(_i(o['xp']))} XP', kind: BtnKind.accent, onPressed: () => Navigator.pop(ctx, true)),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = '${o['code']}');
    try {
      await ref.read(supabaseProvider).rpc('xp_buy_premium', params: {'p_plan': o['code']});
      HapticFeedback.mediumImpact();
      ref.invalidate(myXpProvider);
      ref.invalidate(myPlanProvider);
      if (mounted) toast(context, '${o['name']} is on. Enjoy every year and every exam!', icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill));
    } catch (e) {
      if (mounted) toast(context, xpError(e), icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListCard(
      children: [
        for (final o in widget.options)
          Padding(
            padding: const EdgeInsets.all(Space.s3),
            child: Row(
              children: [
                IconTile(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), tone: Tone.gold, size: 36, radius: 10, iconSize: 18),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${o['name']}', style: context.ty.sm.bold),
                      Text(
                        widget.balance >= _i(o['xp']) ? 'You have enough XP' : '${xpText(_i(o['xp']) - widget.balance)} XP more needed',
                        style: context.ty.cap.col(widget.balance >= _i(o['xp']) ? c.success : c.textMuted),
                      ),
                    ],
                  ),
                ),
                Btn(
                  '${xpText(_i(o['xp']))} XP',
                  kind: widget.balance >= _i(o['xp']) ? BtnKind.accent : BtnKind.tonal,
                  sm: true,
                  loading: _busy == '${o['code']}',
                  onPressed: _busy != null || widget.balance < _i(o['xp']) ? null : () => _buy(o),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// XP packs for money (D-084): Paystack in the direct app (and the Play app only when the admin allows Paystack there).
/// The server sets the price and adds the XP only after Paystack confirms the payment. Bought XP never enters cash challenges.
class _BuyXp extends ConsumerStatefulWidget {
  const _BuyXp({required this.packs});
  final List<Map<String, dynamic>> packs;
  @override
  ConsumerState<_BuyXp> createState() => _BuyXpState();
}

class _BuyXpState extends ConsumerState<_BuyXp> with WidgetsBindingObserver {
  int? _busy;
  String? _reference;
  int? _pendingXp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _reference != null) _check();
  }

  PaystackProvider get _pay => ref.read(paymentProvider(true)) as PaystackProvider;

  /// Pick how to pay (card in Paystack's sheet, bank transfer or USSD on our screen), then pay.
  Future<void> _buy(int xp, int nairaPrice) async {
    var method = PayMethod.card;
    var bank = '737';
    final go = await showSheet<bool>(
      context,
      closeButton: false, // like the plan sheet: swipe down or tap outside to close (owner, 2026-11-05)
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const XpCoin(size: 36),
                const Gap(Space.s3),
                Expanded(child: Text('${xpText(xp)} XP', style: ctx.ty.h3.tnum)),
                Text('₦${xpText(nairaPrice)}', style: ctx.ty.h3.tnum),
              ],
            ),
            const Gap(Space.s4),
            PayMethodPicker(method: method, bank: bank, onChanged: (m, b) => set(() => (method = m, bank = b))),
            const Gap(Space.s4),
            Btn('Pay ₦${xpText(nairaPrice)}', block: true, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = xp);
    final p = _pay..dark = Theme.of(context).brightness == Brightness.dark;
    final r = await p.buyXp(xp, channel: payChannel(method, bank));
    if (!mounted) return;
    setState(() => _busy = null);
    _done(r, xp, via: method.viaName);
  }

  void _done(PayResult r, int xp, {String? via}) {
    switch (r) {
      case PaySuccess():
        HapticFeedback.mediumImpact();
        ref.invalidate(myXpProvider);
        toast(context, '+${xpText(xp)} XP added. Thank you!', icon: PhosphorIcons.coins(PhosphorIconsStyle.fill));
        setState(() => _reference = null);
      case PayOffline():
        setState(() => (_reference = r.reference, _pendingXp = xp));
        showPayOffline(context, r, _pay, what: '${xpText(xp)} XP').then((res) {
          if (!mounted) return;
          if (res == null || res is PayPending) {
            _check();
          } else {
            _done(res, xp);
          }
        });
      case PayWeb():
        setState(() => (_reference = r.reference, _pendingXp = xp));
        showPaystackWeb(context, r, _pay, what: '${xpText(xp)} XP', via: via).then((res) {
          if (!mounted) return;
          if (res == null || res is PayPending) {
            _check();
          } else {
            _done(res, xp);
          }
        });
      case PayPending(:final reference):
        setState(() {
          _reference = reference;
          _pendingXp = xp;
        });
        _check();
      case PayFailed(:final message):
        toast(context, message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        setState(() => _reference = null);
      case PayCancelled():
        // Left or cancelled before paying (D-095): nothing is waiting any more.
        if (_reference != null) toast(context, 'Payment cancelled. You were not charged.', icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill));
        setState(() => _reference = null);
    }
  }

  Future<void> _check() async {
    final r = _reference;
    if (r == null) return;
    for (var i = 0; i < 24 && mounted && _reference == r; i++) {
      final res = await _pay.check(r);
      if (!mounted) return;
      if (res is PaySuccess) {
        HapticFeedback.mediumImpact();
        ref.invalidate(myXpProvider);
        toast(context, '+${_pendingXp ?? ''} XP added. Thank you!', icon: PhosphorIcons.coins(PhosphorIconsStyle.fill));
        setState(() => _reference = null);
        return;
      }
      if (res is PayFailed) {
        toast(context, res.message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        setState(() => _reference = null);
        return;
      }
      if (res is PayCancelled) {
        setState(() => _reference = null);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!usesPaystackNow(ref)) {
      return Text('Buying XP in the Play Store app is coming soon.', style: context.ty.cap.col(c.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reference != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: InfoBanner(
              icon: PhosphorIcons.hourglass(PhosphorIconsStyle.fill),
              child: Row(
                children: [
                  const Expanded(child: Text('Waiting for your payment. We add your XP as soon as it is confirmed.')),
                  TextButton(onPressed: _check, child: const Text('Check')),
                ],
              ),
            ),
          ),
        ListCard(
          children: [
            for (final p in widget.packs)
              Padding(
                padding: const EdgeInsets.all(Space.s3),
                child: Row(
                  children: [
                    const XpCoin(size: 32),
                    const Gap(Space.s3),
                    Expanded(child: Text('${xpText(_i(p['xp']))} XP', style: context.ty.body.bold.tnum)),
                    Btn(
                      '₦${xpText(_i(p['naira']))}',
                      kind: BtnKind.tonal,
                      sm: true,
                      loading: _busy == _i(p['xp']),
                      onPressed: _busy != null || _reference != null ? null : () => _buy(_i(p['xp']), _i(p['naira'])),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const Gap(Space.s2),
        Text('Bought XP can be spent on Premium, events and streak freezes, but not on cash-prize challenges.', style: context.ty.cap.col(c.textSubtle)),
      ],
    );
  }
}

/// "Watch a video, earn XP" (rewarded video, server-verified; the admin sets videos, XP and the daily cap). XP from
/// videos is kept like bought XP: it can be spent in the app, never on cash-prize entries (AdMob rule).
class WatchForXpCard extends ConsumerStatefulWidget {
  const WatchForXpCard({super.key});
  @override
  ConsumerState<WatchForXpCard> createState() => _WatchForXpCardState();
}

class _WatchForXpCardState extends ConsumerState<WatchForXpCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    final xp = a.reward('xp_amount');
    if (!a.format('rewarded') || xp <= 0) return const SizedBox.shrink();
    final need = a.reward('xp_ads') > 1 ? a.reward('xp_ads') : 1;
    final left = a.xpLeft;
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s3),
      child: AppCard(
        child: Row(
          children: [
            IconTile(PhosphorIcons.playCircle(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12, iconSize: 24),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(need > 1 ? 'Watch $need videos, earn +$xp XP' : 'Watch a video, earn +$xp XP', style: context.ty.sm.bold),
                  const Gap(2),
                  Text(
                    left <= 0
                        ? 'All done for today. Come back tomorrow.'
                        : need > 1
                        ? '${a.xpProgress} of $need watched · $left videos left today'
                        : '$left videos left today',
                    style: context.ty.cap.col(c.textMuted),
                  ),
                ],
              ),
            ),
            const Gap(Space.s3),
            Btn(
              'Watch',
              sm: true,
              kind: BtnKind.tonal,
              loading: _busy,
              onPressed: left <= 0 || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final r = await watchForReward(context, ref, kind: 'xp', placement: 'xp_wallet');
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (r.granted) {
                        ref.invalidate(myXpProvider);
                        toast(this.context, '+$xp XP added to your wallet.', icon: PhosphorIcons.coins(PhosphorIconsStyle.fill));
                      } else if (r.counted) {
                        toast(this.context, '${r.count} of ${r.need} videos watched.', icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
