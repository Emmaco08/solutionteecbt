import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
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
};

/// Opens the Premium paywall bottom sheet (prototype `paywall`).
Future<void> showPaywall(BuildContext context, {String? reason}) {
  final head = _reasons[reason] ?? (RegExp(r'\d{4}$').hasMatch(reason ?? '') ? '$reason is Premium' : 'Go Premium');
  return showSheet<void>(context, builder: (_) => _Paywall(head: head));
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
  final out = <String>[];
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
  return out.take(7).toList();
}

class _Paywall extends ConsumerStatefulWidget {
  const _Paywall({required this.head});
  final String head;
  @override
  ConsumerState<_Paywall> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<_Paywall> {
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
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(14)),
              child: Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 28, color: Palette.navy900),
            ),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.head, style: context.ty.h2),
                  Text('Unlock everything and practise without limits.', style: context.ty.sm.col(c.textMuted)),
                ],
              ),
            ),
          ],
        ),
        const Gap(Space.s4),
        for (final (i, b) in benefits.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 20, color: c.success),
                const Gap(Space.s3),
                Expanded(
                  child: Text(b, style: context.ty.sm.copyWith(height: 20 / 14)),
                ),
              ],
            ),
          ).animate(target: rm ? 0 : 1).fadeIn(delay: (40 * i).ms, duration: Motion.base).slideY(begin: .2, end: 0),
        const Gap(Space.s1),
        Row(
          children: [
            Expanded(child: Text('Choose a plan', style: context.ty.label)),
            if (sample) const Pill('SAMPLE PRICES', kind: BadgeKind.sample),
          ],
        ),
        const Gap(Space.s3),
        for (final p in plans) ...[
          _PlanRow(plan: p, price: price(p), on: identical(p, pick), onTap: () => setState(() => _pick = p['code'] as String)),
          const Gap(Space.s3),
        ],
        const Gap(Space.s1),
        Btn(
          pick.isEmpty ? 'Continue' : 'Continue with ${pick['name']} · ${price(pick)}',
          block: true,
          onPressed: pick.isEmpty
              ? null
              : () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push('/checkout?plan=${Uri.encodeQueryComponent('${pick['code']}')}');
                },
        ),
        const Gap(Space.s3),
        Text(
          'Secure payment. Premium starts as soon as payment is confirmed.${usesPaystack(ref) ? ' Have a discount code? Add it at checkout.' : ''}',
          textAlign: TextAlign.center,
          style: context.ty.cap.col(c.textMuted),
        ),
      ],
    );
  }
}

/// `.plan` row: radio, name + note, price + period; "Best value" badge on the 3-month plan.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.price, required this.on, required this.onTap});
  final Map<String, dynamic> plan;
  final String price;
  final bool on;
  final VoidCallback onTap;

  String get _per => planPeriod(plan);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final note = '${plan['description'] ?? ''}'.replaceFirst(RegExp(r'^SAMPLE price\.\s*'), '');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Pressable(
          onTap: onTap,
          scale: .985,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: on ? c.primarySoft : c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: on ? c.primary : c.border, width: on ? 2 : 1.5),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: on ? c.primary : c.borderStrong, width: on ? 7 : 2),
                  ),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${plan['name']}', style: context.ty.body.bold),
                      if (note.isNotEmpty) Text(note, style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: context.ty.body.bold.tnum.copyWith(fontSize: 18)),
                    Text(_per, style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (plan['code'] == 'three_months') const Positioned(top: -11, left: 16, child: Pill('Best value', kind: BadgeKind.gold)),
      ],
    );
  }
}
