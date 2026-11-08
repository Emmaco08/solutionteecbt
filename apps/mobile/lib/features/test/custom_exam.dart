import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../home/home_screen.dart';
import '../premium/paywall.dart';

/// The admin's custom exam settings (app_settings.custom_exam): on, who ('everyone' | 'premium'), limits.
class CustomExamRules {
  CustomExamRules(Map<String, dynamic>? j) : j = j ?? const {};
  final Map<String, dynamic> j;
  bool get on => j['on'] != false;
  bool get premiumOnly => j['who'] == 'premium';
  int get maxQuestions => (j['max_questions'] as num?)?.toInt() ?? 40;
  int get maxEnglish => (j['max_english'] as num?)?.toInt() ?? 60;
  int get maxMinutes => (j['max_minutes'] as num?)?.toInt() ?? 180;

  /// The most questions for one subject: English (Use of English) allows more.
  int maxFor(Map<String, dynamic> subject) => '${subject['code']}' == 'eng' ? maxEnglish : maxQuestions;
}

/// Opens the custom exam, or the paywall when the admin keeps it for Premium.
void openCustomExam(BuildContext context, WidgetRef ref, String exam) {
  final rules = CustomExamRules((ref.read(appSettingsProvider).value ?? const {})['custom_exam'] as Map<String, dynamic>?);
  final premium = ref.read(myPlanProvider).value?['tier'] == 'premium';
  if (rules.premiumOnly && !premium) {
    showPaywall(context, reason: 'custom');
    return;
  }
  context.push('/test/custom?exam=$exam');
}

/// Custom exam (owner, 2026-11-07): the student builds their own test — subjects, questions per subject (at most 40,
/// English 60), topics, years and time.
class CustomExamScreen extends ConsumerStatefulWidget {
  const CustomExamScreen({super.key, required this.examCode});
  final String examCode;
  @override
  ConsumerState<CustomExamScreen> createState() => _CustomExamScreenState();
}

class _CustomExamScreenState extends ConsumerState<CustomExamScreen> {
  final _subjects = <int>{};
  final _counts = <int, int>{};
  final _topics = <int, Set<String>>{};
  final _years = <int>{};
  int? _minutes;
  bool _timed = true, _starting = false, _seeded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final exams = ref.watch(examsProvider).value;
    final subjects = ref.watch(subjectsProvider).value;
    final links = ref.watch(examSubjectsProvider).value;
    final open = ref.watch(openYearsProvider).value ?? const [];
    final topics = ref.watch(topicsProvider).value ?? const [];
    final profile = ref.watch(profileProvider).value;
    final rules = CustomExamRules((ref.watch(appSettingsProvider).value ?? const {})['custom_exam'] as Map<String, dynamic>?);
    if (exams == null || subjects == null || links == null) {
      return const Scaffold(
        appBar: TopBar(title: 'Custom exam'),
        body: ListSkeleton(),
      );
    }
    if (!rules.on) {
      return Scaffold(
        appBar: const TopBar(title: 'Custom exam'),
        body: StateBlock(icon: PhosphorIcons.listChecks(PhosphorIconsStyle.fill), tone: Tone.neutral, title: 'Custom exams are not available right now'),
      );
    }
    final exam = exams.where((e) => e['code'] == widget.examCode).firstOrNull ?? exams.first;
    final examId = (exam['id'] as num).toInt();
    final available = {for (final r in links.where((r) => r['exam_id'] == examId)) r['subject_id']};
    var subs = subjects.where((s) => available.contains(s['id'])).toList();
    final jambCodes = ((profile?['jamb_subjects'] as List?) ?? const []).cast<String>();
    if (widget.examCode == 'JAMB' && jambCodes.isNotEmpty) {
      // The student's own JAMB subjects first.
      subs.sort((a, b) => (jambCodes.contains(b['code']) ? 1 : 0) - (jambCodes.contains(a['code']) ? 1 : 0));
    }
    if (!_seeded) {
      _seeded = true;
      for (final s in subs.where((s) => widget.examCode != 'JAMB' || jambCodes.contains(s['code'])).take(4)) {
        final id = (s['id'] as num).toInt();
        _subjects.add(id);
        _counts[id] = '${s['code']}' == 'eng' ? 60 : 40;
      }
      if (_subjects.isEmpty && subs.isNotEmpty) {
        final id = (subs.first['id'] as num).toInt();
        _subjects.add(id);
        _counts[id] = 20;
      }
    }
    final yearsOpen = ({
      for (final y in open)
        if (y['exam_id'] == examId && y['cbt_open'] == true && _subjects.contains(y['subject_id'])) (y['year'] as num).toInt(),
    }.toList()..sort((a, b) => b.compareTo(a)));
    _years.removeWhere((y) => !yearsOpen.contains(y));
    final total = _subjects.fold<int>(0, (t, id) => t + (_counts[id] ?? 20));
    final suggested = (total * (widget.examCode == 'JAMB' ? 120 / 180 : 1.0)).round().clamp(5, rules.maxMinutes);
    final minutes = (_minutes ?? suggested).clamp(5, rules.maxMinutes);

    Widget block(String title, Widget child, {String? help}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.ty.sm.bold),
          if (help != null) Text(help, style: context.ty.cap.col(c.textMuted)),
          const Gap(Space.s2),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: TopBar(title: 'Custom ${widget.examCode} exam'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          Text('Build your own test: pick the subjects, how many questions, the topics, the years and the time.', style: context.ty.sm.col(c.textMuted)),
          const Gap(Space.s4),
          block(
            'Subjects',
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                for (final s in subs)
                  AppChip(
                    '${s['name']}',
                    on: _subjects.contains((s['id'] as num).toInt()),
                    onTap: () => setState(() {
                      final id = (s['id'] as num).toInt();
                      if (_subjects.contains(id)) {
                        _subjects.remove(id);
                      } else {
                        _subjects.add(id);
                        _counts.putIfAbsent(id, () => 20.clamp(1, rules.maxFor(s)));
                      }
                    }),
                  ),
              ],
            ),
          ),
          for (final s in subs.where((s) => _subjects.contains((s['id'] as num).toInt())))
            Builder(
              builder: (_) {
                final id = (s['id'] as num).toInt();
                final max = rules.maxFor(s);
                final n = (_counts[id] ?? 20).clamp(5, max);
                final ts = topics.where((t) => t['subject_id'] == id).map((t) => '${t['name']}').toList();
                final picked = _topics[id] ?? <String>{};
                return Padding(
                  padding: const EdgeInsets.only(bottom: Space.s4),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${s['name']}', style: context.ty.body.bold)),
                            Text('$n questions', style: context.ty.sm.bold.tnum),
                          ],
                        ),
                        Slider(
                          value: n.toDouble(),
                          min: 5,
                          max: max.toDouble(),
                          divisions: max - 5,
                          label: '$n',
                          onChanged: (v) => setState(() => _counts[id] = v.round()),
                        ),
                        Text('Up to $max for this subject.', style: context.ty.cap.col(c.textMuted)),
                        if (ts.isNotEmpty) ...[
                          const Gap(Space.s3),
                          Text(picked.isEmpty ? 'Topics: all' : 'Topics: ${picked.length} chosen', style: context.ty.cap.bold),
                          const Gap(Space.s1),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final t in ts) ...[
                                  AppChip(
                                    t,
                                    on: picked.contains(t),
                                    onTap: () => setState(() {
                                      final set = _topics.putIfAbsent(id, () => <String>{});
                                      set.contains(t) ? set.remove(t) : set.add(t);
                                    }),
                                  ),
                                  const Gap(Space.s2),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          block(
            'Years',
            yearsOpen.isEmpty
                ? Text('Your open years are used.', style: context.ty.sm.col(c.textMuted))
                : Wrap(
                    spacing: Space.s2,
                    runSpacing: Space.s2,
                    children: [
                      AppChip('All my years', on: _years.isEmpty, onTap: () => setState(_years.clear)),
                      for (final y in yearsOpen)
                        AppChip('$y', on: _years.contains(y), onTap: () => setState(() => _years.contains(y) ? _years.remove(y) : _years.add(y))),
                    ],
                  ),
            help: 'Only years open on your plan are listed.',
          ),
          block(
            'Time',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_timed ? '$minutes minutes' : 'No clock', style: context.ty.body.bold.tnum)),
                    AppSwitch(value: _timed, onChanged: (v) => setState(() => _timed = v)),
                  ],
                ),
                if (_timed)
                  Slider(
                    value: minutes.toDouble(),
                    min: 5,
                    max: rules.maxMinutes.toDouble(),
                    divisions: (rules.maxMinutes - 5) ~/ 5,
                    label: '$minutes min',
                    onChanged: (v) => setState(() => _minutes = (v / 5).round() * 5),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Btn(
          _subjects.isEmpty ? 'Pick at least one subject' : 'Start · $total questions',
          block: true,
          loading: _starting,
          onPressed: _subjects.isEmpty ? null : () => _start(examId, subs, minutes),
        ),
      ),
    );
  }

  Future<void> _start(int examId, List<Map<String, dynamic>> subs, int minutes) async {
    final order = [for (final s in subs) (s['id'] as num).toInt()].where(_subjects.contains).toList();
    setState(() => _starting = true);
    try {
      final id = await ref
          .read(testsRepoProvider)
          .start(
            TestRequest(
              mode: TestMode.custom,
              examId: examId,
              examCode: widget.examCode,
              subjectIds: order,
              years: _years.toList(),
              counts: {for (final s in order) s: _counts[s] ?? 20},
              subjectTopics: {
                for (final s in order)
                  if ((_topics[s] ?? const {}).isNotEmpty) s: _topics[s]!.toList(),
              },
              topics: [for (final s in order) ...?_topics[s]],
              limitMinutes: minutes,
              timed: _timed,
              title: 'Custom ${widget.examCode} exam',
            ),
            countFor: (sid) => _counts[sid] ?? 20,
            minutesPerQuestion: 1,
          );
      ref.invalidate(unfinishedProvider);
      ref.invalidate(practiceStatsProvider);
      if (mounted) context.pushReplacement('/cbt/$id');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}
