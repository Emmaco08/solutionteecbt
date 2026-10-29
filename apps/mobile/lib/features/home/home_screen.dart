import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/states.dart';
import '../shell/shell.dart';

/// The unfinished test on this phone (if any), for the "Continue" card.
final unfinishedProvider = FutureProvider<LocalAttempt?>((ref) => ref.watch(dbProvider).unfinishedAttempt());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profile = ref.watch(profileProvider).value;
    final name = ((profile?['full_name'] as String?) ?? '').split(' ').first;
    final plan = ref.watch(myPlanProvider).value;
    final premium = plan?['tier'] == 'premium';
    final exams = ref.watch(examsProvider);
    final unfinished = ref.watch(unfinishedProvider).value;
    final news = ref.watch(newsProvider).value ?? const [];

    Future<void> refresh() async {
      ref.invalidate(examsProvider);
      ref.invalidate(myPlanProvider);
      ref.invalidate(newsProvider);
      ref.invalidate(openYearsProvider);
      ref.invalidate(unfinishedProvider);
      await ref.read(examsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
    }

    final sections = <Widget>[
      // Greeting
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: context.t.bodyMedium?.copyWith(color: c.textMuted)),
                Text(name.isEmpty ? 'Welcome' : name, style: context.t.headlineMedium),
              ],
            ),
          ),
          _PlanBadge(premium: premium),
        ],
      ),
      if (unfinished != null) _ContinueCard(a: unfinished),
      Text('Start a CBT practice', style: context.t.titleMedium),
      asyncView(
        exams,
        (list) => Column(
          children: [
            for (final e in list) ...[_ExamCard(code: e['code'] as String, name: e['name'] as String, config: (e['exam_configs'] as Map?) ?? const {}), gap3],
          ],
        ),
        loading: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[const Skeleton(height: 84, radius: Radii.lg), gap3],
          ],
        ),
        onRetry: refresh,
      ),
      if (news.isNotEmpty) ...[
        Text('News', style: context.t.titleMedium),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: news.length,
            separatorBuilder: (_, _) => gap3,
            itemBuilder: (_, i) => _NewsCard(n: news[i]),
          ),
        ),
      ],
      if (!premium) _UpgradeCard(),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
            itemCount: sections.length,
            separatorBuilder: (_, _) => gap5,
            itemBuilder: (_, i) => context.reduceMotion
                ? sections[i]
                : sections[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.base).slideY(begin: .06, curve: Motion.out),
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.premium});
  final bool premium;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 6),
      decoration: BoxDecoration(color: premium ? c.accent : c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(premium ? PhosphorIcons.crown(PhosphorIconsStyle.fill) : PhosphorIcons.user(), size: 16, color: premium ? c.onAccent : c.textMuted),
          const SizedBox(width: 6),
          Text(
            premium ? 'Premium' : 'Free plan',
            style: context.t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: premium ? c.onAccent : c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.a});
  final LocalAttempt a;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cfg = jsonDecode(a.configJson) as Map<String, dynamic>;
    final total = (jsonDecode(a.questionIdsJson) as List).length;
    return Material(
      color: c.primary,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push('/cbt/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            children: [
              Icon(PhosphorIcons.playCircle(PhosphorIconsStyle.fill), color: c.accent, size: 40),
              gap4,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Continue your test', style: context.t.titleMedium?.copyWith(color: c.onPrimary)),
                    Text(
                      '${(cfg['title'] as String?)?.isNotEmpty == true ? cfg['title'] : a.examCode} · question ${a.currentIndex + 1} of $total',
                      style: context.t.bodySmall?.copyWith(color: c.onPrimary.withValues(alpha: .8)),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIcons.caretRight(), color: c.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.code, required this.name, required this.config});
  final String code, name;
  final Map config;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sub = code == 'JAMB'
        ? '${config['subjects_per_candidate'] ?? 4} subjects · ${config['total_minutes'] ?? 120} mins · scored /${config['score_scale'] ?? 400}'
        : 'Objective papers by subject and year';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push('/test/setup?exam=$code'),
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            children: [
              ExamLogo(code, size: 52),
              gap4,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.t.titleMedium),
                    Text(sub, style: context.t.bodySmall),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), color: c.onPrimary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.n});
  final Map<String, dynamic> n;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 260,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: .7,
              builder: (_, sc) => ListView(
                controller: sc,
                padding: const EdgeInsets.all(Space.s5),
                children: [
                  Text(n['title'] as String, style: context.t.headlineSmall),
                  gap3,
                  Text((n['body'] as String?) ?? (n['summary'] as String?) ?? '', style: context.t.bodyLarge),
                ],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.newspaper(PhosphorIconsStyle.fill), size: 18, color: c.secondary),
                    const SizedBox(width: 6),
                    if (n['is_pinned'] == true)
                      Text(
                        'Pinned',
                        style: context.t.labelSmall?.copyWith(color: c.onAccentSoft, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                gap2,
                Text(n['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.t.labelLarge),
                const Spacer(),
                Text((n['summary'] as String?) ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.t.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill), color: c.onAccentSoft, size: 32),
          gap4,
          Expanded(
            child: Text(
              'Premium opens every year, video solutions, notes and more AI help. Coming soon in the app.',
              style: context.t.bodyMedium?.copyWith(color: c.onAccentSoft),
            ),
          ),
        ],
      ),
    );
  }
}
