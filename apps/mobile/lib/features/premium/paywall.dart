import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'checkout.dart' show showRedeemSheet;
import 'content_offer.dart';
import 'payments.dart';

/// Why the paywall opened: an exam code, a year, or a study kind / feature.
const _reasons = {
  'WAEC': 'WAEC is a Premium exam',
  'NECO': 'NECO is a Premium exam',
  'video_solution': 'This video is Premium',
  'lesson': 'Topic lessons are Premium',
  'note': 'Lesson notes are Premium',
  'novel': 'Novels are Premium',
  'doc': 'This document is Premium',
  'offline': 'Downloads are Premium',
  'ai': 'Get more AI prompts',
  'years': 'More years are Premium',
  'classes': 'This class is for Premium students',
};

/// Opens the Premium paywall bottom sheet (prototype `paywall`).
Future<void> showPaywall(BuildContext context, {String? reason}) {
  final head =
      _reasons[reason] ??
      (RegExp(r'\d{4}$').hasMatch(reason ?? '')
          ? '$reason is Premium'
          : RegExp(r'^[A-Z][A-Z0-9]{1,11}$').hasMatch(reason ?? '')
          ? '$reason is a Premium exam'
          : 'Go Premium');
  return showSheet<void>(context, closeButton: false, builder: (_) => _Paywall(head: head));
}

/// How long a plan lasts, e.g. "3 months" or "Until 31 Jul 2027".
String planPeriod(Map<String, dynamic> plan) {
  final d = (plan['duration_days'] as num?)?.toInt();
  if (d != null) return d % 30 == 0 ? (d == 30 ? '1 month' : '${d ~/ 30} months') : '$d days';
  final e = DateTime.tryParse('${plan['ends_on']}');
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return e == null ? '' : 'Until ${e.day} ${m[e.month - 1]} ${e.year}';
}

String naira(num kobo) {
  final s = (kobo / 100).round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₦$s';
}

/// Paywall benefits written from the admin's Free vs Premium rules, so they stay true (prototype `premiumBenefits`).
List<String> premiumBenefits(Map<String, Map<String, dynamic>> a) {
  final f = a['free'] ?? const {}, p = a['premium'] ?? const {};
  String y(Object? v) => v == 'all' ? 'every year' : '$v years';
  // Premium never shows ads (the server gives Premium no ads at any level).
  final out = <String>['No ads at all: no banners, no video breaks'];
  for (final k in ['jamb', 'waec', 'neco']) {
    if (p[k] != f[k]) out.add('${k.toUpperCase()} CBT: ${y(p[k])}${(f[k] is num && f[k] > 0) ? ' (Free: ${y(f[k])})' : ' (not on Free)'}');
  }
  if (p['pq'] != f['pq']) out.add('Past questions with answers: ${y(p['pq'])} (Free: ${y(f['pq'])})');
  final feats = [
    for (final (k, n) in [('videos', 'Video solutions'), ('lessons', 'Topic video lessons'), ('notes', 'Lesson notes'), ('novels', 'Novel summaries')])
      if (p[k] == true && f[k] != true) n,
  ];
  if (feats.isNotEmpty) out.add(feats.join(', '));
  if (p['syllabus'] != f['syllabus']) out.add('Syllabuses and brochure: ${p['syllabus'] == 'all' ? 'all' : p['syllabus']} (Free: ${f['syllabus']})');
  if (p['ai'] != f['ai']) out.add('${p['ai']} AI tutor prompts a day (Free: ${f['ai']})');
  if (p['offline'] == true && f['offline'] != true) out.add('Download lessons and practise offline, without data');
  return out.take(8).toList();
}

class _Paywall extends ConsumerStatefulWidget {
  const _Paywall({required this.head});
  final String head;
  @override
  ConsumerState<_Paywall> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<_Paywall> {
  @override
  void initState() {
    super.initState();
    AdsGate.enter(); // no ads at checkout
  }

  @override
  void dispose() {
    AdsGate.leave();
    super.dispose();
  }

  String? _pick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rules = ref.watch(accessRulesProvider).value ?? const {};
    final plans = ref.watch(plansForSaleProvider).value ?? ref.watch(plansProvider).value ?? const [];
    // Play build: Google's own price text (Google charges its own price, set in Play Console).
    final playPrices = usesPaystack(ref) ? const <String, String>{} : (ref.watch(playPricesProvider).value ?? const {});
    String price(Map<String, dynamic> p) => playPrices['${p['play_product_id'] ?? ''}'] ?? naira(p['price_kobo'] as num);
    final sample = plans.any((p) => '${p['description'] ?? ''}'.startsWith('SAMPLE'));
    final benefits = premiumBenefits(rules);
    final pick = firstOr(plans, (p) => p['code'] == (_pick ?? 'three_months'), fallbackFirst: true);
    // Play app (D-113): the admin offers Google Play, the payment website, or both.
    final ps = ref.watch(paySettingsProvider);
    final playApp = !usesPaystack(ref);
    final google = !playApp || ps.playGoogle, website = playApp && ps.playWebsite;
    final rm = context.reduceMotion;
    Widget enter(Widget w, int i) =>
        rm ? w : w.animate().fadeIn(delay: (60 + 45 * i).ms, duration: 320.ms).slideY(begin: .12, end: 0, curve: Curves.easeOutCubic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navy hero with a floating, shining crown
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy900, Color(0xFF173A7A)]),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color.fromRGBO(242, 178, 51, .35), Color.fromRGBO(242, 178, 51, 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.s4),
                  child: Row(
                    children: [
                      _Crown(still: rm),
                      const Gap(Space.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.head, style: context.ty.h2.col(Colors.white)),
                            const SizedBox(height: 2),
                            Text('Unlock everything and practise without limits.', style: context.ty.sm.col(const Color(0xFFC9D5EA))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: rm ? 1.ms : 300.ms).scaleXY(begin: rm ? 1 : .97, end: 1, duration: rm ? 1.ms : 380.ms, curve: Curves.easeOutBack),
        const Gap(Space.s4),
        for (final (i, b) in benefits.indexed)
          enter(
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: c.successSoft, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.check(), size: 14, color: c.success),
                  ),
                  const Gap(Space.s3),
                  Expanded(
                    child: Text(b, style: context.ty.sm.copyWith(height: 20 / 14)),
                  ),
                ],
              ),
            ),
            i,
          ),
        const Gap(Space.s3),
        Row(
          children: [
            Expanded(child: Text('Choose a plan', style: context.ty.h3)),
            if (sample) const Pill('SAMPLE PRICES', kind: BadgeKind.sample),
          ],
        ),
        const Gap(Space.s4),
        for (final (i, p) in plans.indexed) ...[
          enter(_PlanRow(plan: p, price: price(p), on: identical(p, pick), onTap: () => setState(() => _pick = p['code'] as String)), benefits.length + i),
          const Gap(Space.s4),
        ],
        if (google)
          Btn(
            pick.isEmpty ? 'Continue' : 'Continue · ${price(pick)}',
            kind: BtnKind.accent,
            block: true,
            icon: PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
            onPressed: pick.isEmpty
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/checkout?plan=${Uri.encodeQueryComponent('${pick['code']}')}');
                  },
          ),
        if (google && website) const Gap(Space.s3),
        if (website)
          Btn(
            google ? 'Pay on our website instead' : (pick.isEmpty ? 'Pay on our website' : 'Pay on our website · ${naira(pick['price_kobo'] as num)}'),
            kind: google ? BtnKind.outline : BtnKind.accent,
            block: true,
            icon: PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.bold),
            onPressed: pick.isEmpty
                ? null
                : () async {
                    HapticFeedback.selectionClick();
                    final ok = await openPayWebsite(ref, plan: '${pick['code']}');
                    if (!ok && context.mounted) toast(context, 'Could not open the website. Please try again.');
                  },
          ),
        // Google Play app (D-117): codes — free Premium days here, discount codes on the website (when offered).
        if (playApp && showsRedeem(ref))
          TextButton.icon(
            onPressed: pick.isEmpty ? null : () => showRedeemSheet(context, plan: '${pick['code']}'),
            icon: Icon(PhosphorIcons.ticket(), size: 18),
            label: const Text('Have a code?'),
          ),
        const Gap(Space.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 14, color: c.textMuted),
            const Gap(Space.s1),
            Flexible(
              child: Text(
                !playApp
                    ? 'Card · Transfer · USSD · OPay · Zap · Bank apps'
                    : website && google
                    ? 'Google Play here, or card · transfer · USSD · OPay on our website'
                    : website
                    ? 'Card · Transfer · USSD · OPay on our website'
                    : 'Paid securely with Google Play',
                style: context.ty.cap.bold.col(c.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const Gap(Space.s1),
        Text(
          website
              ? 'Pay on the website with the same email you use here. Premium shows in the app as soon as the payment is confirmed.'
              : 'Premium starts as soon as the payment is confirmed.${usesPaystack(ref) ? ' Have a discount code? Add it at checkout.' : ''}',
          textAlign: TextAlign.center,
          style: context.ty.cap.col(c.textSubtle),
        ),
      ],
    );
  }
}

/// The gold crown tile: floats gently, with a shine passing over it now and then.
class _Crown extends StatelessWidget {
  const _Crown({this.still = false});
  final bool still;
  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD66B), Palette.gold500]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Palette.gold400.withValues(alpha: .4), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 30, color: Palette.navy900),
    );
    if (still) return tile;
    return tile
        .animate(onPlay: (a) => a.repeat())
        .shimmer(delay: 1800.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: .55))
        .animate(onPlay: (a) => a.repeat(reverse: true))
        .moveY(begin: -2, end: 2, duration: 1600.ms, curve: Curves.easeInOut);
  }
}

/// A plan card: name + note, price + period (and the price per month for longer plans), a tick that pops in, a gold
/// glow and a small lift when chosen; "Best value" ribbon on the 3-month plan.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.price, required this.on, required this.onTap});
  final Map<String, dynamic> plan;
  final String price;
  final bool on;
  final VoidCallback onTap;

  String get _per => planPeriod(plan);

  /// "₦1,167 a month" for plans of 2 months or more.
  String? get _monthly {
    final d = (plan['duration_days'] as num?)?.toInt();
    final k = (plan['price_kobo'] as num?)?.toInt();
    if (d == null || k == null || d < 60) return null;
    return '${naira(k / (d / 30))} a month';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final best = plan['code'] == 'three_months';
    final note = '${plan['description'] ?? ''}'.replaceFirst(RegExp(r'^SAMPLE price\.\s*'), '');
    final monthly = _monthly;
    return Semantics(
      selected: on,
      button: true,
      label: '${plan['name']}, $price',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedScale(
            scale: on ? 1 : .985,
            duration: rm ? Duration.zero : Motion.base,
            curve: Curves.easeOutBack,
            child: Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              scale: .98,
              borderRadius: BorderRadius.circular(Radii.lg),
              child: AnimatedContainer(
                duration: rm ? Duration.zero : Motion.base,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4 + 2, Space.s4, Space.s4),
                decoration: BoxDecoration(
                  color: on ? c.primarySoft : c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: on ? Palette.gold400 : c.border, width: on ? 2 : 1.5),
                  boxShadow: on ? [BoxShadow(color: Palette.gold400.withValues(alpha: .22), blurRadius: 18, spreadRadius: 1)] : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: rm ? Duration.zero : Motion.fast,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? Palette.gold400 : Colors.transparent,
                        border: Border.all(color: on ? Palette.gold400 : c.borderStrong, width: 2),
                      ),
                      child: on
                          ? Icon(
                              PhosphorIcons.check(),
                              size: 15,
                              color: Palette.navy900,
                            ).animate().scaleXY(begin: rm ? 1 : .3, end: 1, duration: rm ? 1.ms : 260.ms, curve: Curves.easeOutBack)
                          : null,
                    ),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${plan['name']}', style: context.ty.body.bold),
                          if (note.isNotEmpty) ...[const SizedBox(height: 2), Text(note, style: context.ty.cap.col(c.textMuted))],
                        ],
                      ),
                    ),
                    const Gap(Space.s2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price, style: context.ty.h3.tnum),
                        Text(_per, style: context.ty.cap.col(c.textMuted)),
                        if (monthly != null) Text(monthly, style: context.ty.cap.bold.col(c.success)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (best)
            Positioned(
              top: -12,
              left: 16,
              child: rm
                  ? const Pill('Best value', kind: BadgeKind.gold)
                  : const Pill(
                      'Best value',
                      kind: BadgeKind.gold,
                    ).animate(onPlay: (a) => a.repeat()).shimmer(delay: 2200.ms, duration: 1100.ms, color: Colors.white.withValues(alpha: .7)),
            ),
        ],
      ),
    );
  }
}

/// A locked past-question year (D-104, D-106): how it opens is the admin's choice (watch N videos for a while, pay for
/// this year, or Premium). [years] are the locked years to choose from (newest first); one year goes straight on.
Future<void> showYearUnlock(BuildContext context, WidgetRef ref, {required int examId, required String exam, required List<int> years}) async {
  if (years.isEmpty) return showPaywall(context, reason: 'years');
  var year = years.first;
  if (years.length > 1) {
    final picked = await showSheet<int>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Open another $exam year', style: ctx.ty.h2),
          const Gap(Space.s2),
          Text('Pick the year you want.', style: ctx.ty.body.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [for (final y in years) AppChip('$y', on: false, onTap: () => Navigator.pop(ctx, y))],
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    year = picked;
  }
  if (!context.mounted) return;
  await showContentOffer(
    context,
    kind: 'year',
    itemRef: '$examId:$year',
    title: '$exam $year',
    paywallReason: '$exam $year',
    onOpened: () => ref.invalidate(openYearsProvider),
  );
}
