import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/states.dart';
import '../home/home_screen.dart';
import '../shell/shell.dart';

/// Test tab: pick an exam (with its real logo), continue an unfinished test, see history.
class TestHubScreen extends ConsumerWidget {
  const TestHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    final unfinished = ref.watch(unfinishedProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice tests'),
        actions: [IconButton(tooltip: 'Test history', icon: Icon(PhosphorIcons.clockCounterClockwise()), onPressed: () => context.push('/history'))],
      ),
      body: asyncView(
        exams,
        (list) => ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s8),
          children: [
            if (unfinished != null) ...[
              Card(
                child: ListTile(
                  leading: Icon(PhosphorIcons.playCircle(PhosphorIconsStyle.fill), color: context.c.secondary, size: 32),
                  title: const Text('Continue your unfinished test'),
                  subtitle: Text('Question ${unfinished.currentIndex + 1}'),
                  trailing: Icon(PhosphorIcons.caretRight()),
                  onTap: () => context.push('/cbt/${unfinished.id}'),
                ),
              ),
              gap4,
            ],
            for (final e in list) ...[_ExamHero(code: e['code'] as String, name: e['name'] as String), gap3],
          ],
        ),
        onRetry: () => ref.invalidate(examsProvider),
      ),
    );
  }
}

class _ExamHero extends StatelessWidget {
  const _ExamHero({required this.code, required this.name});
  final String code, name;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push('/test/setup?exam=$code'),
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            children: [
              ExamLogo(code, size: 64, bare: true),
              gap4,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(code == 'JAMB' ? 'Full JAMB simulation and more' : name, style: context.t.titleMedium),
                    Text(
                      code == 'JAMB' ? '4 subjects · 180 questions · 2 hours, or practise one subject' : 'Practise by subject and year',
                      style: context.t.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIcons.caretRight(), color: c.textSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test setup: mode → subject(s) → year → timed. A new test always starts empty (D-025).
class TestSetupScreen extends ConsumerStatefulWidget {
  const TestSetupScreen({super.key, required this.examCode});
  final String examCode;
  @override
  ConsumerState<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends ConsumerState<TestSetupScreen> {
  TestMode _mode = TestMode.quick;
  int? _subjectId;
  int? _year; // null = any open year
  String? _topic;
  bool _timed = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    if (widget.examCode == 'JAMB') _mode = TestMode.full;
  }

  Future<void> _start(Map<String, dynamic> exam, List<Map<String, dynamic>> subjects, List<Map<String, dynamic>> examSubjects) async {
    final unfinished = await ref.read(dbProvider).unfinishedAttempt();
    if (unfinished != null && mounted) {
      final fresh = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You have an unfinished test'),
          content: const Text('Starting a new test will end the unfinished one.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continue it')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start new')),
          ],
        ),
      );
      if (fresh == null) return;
      if (!fresh) {
        if (mounted) context.pushReplacement('/cbt/${unfinished.id}');
        return;
      }
    }

    final examId = (exam['id'] as num).toInt();
    final cfg = (exam['exam_configs'] as Map?) ?? const {};
    List<int> subjectIds;
    if (_mode == TestMode.full) {
      final codes = ((ref.read(profileProvider).value?['jamb_subjects'] as List?) ?? const []).cast<String>();
      subjectIds = [
        for (final s in subjects)
          if (codes.contains(s['code'])) (s['id'] as num).toInt(),
      ];
      if (subjectIds.length != 4) return _toast('Choose your 4 JAMB subjects in your profile first.');
      // Use of English first, as in the real exam.
      final eng = subjects.firstWhere((s) => s['code'] == 'eng')['id'];
      subjectIds.sort(
        (a, b) => a == eng
            ? -1
            : b == eng
            ? 1
            : a.compareTo(b),
      );
    } else {
      if (_subjectId == null) return _toast('Choose a subject.');
      if (_mode == TestMode.topic && (_topic == null || _topic!.isEmpty)) return _toast('Type a topic, for example Logarithms.');
      subjectIds = [_subjectId!];
    }

    int countFor(int sid) =>
        (examSubjects.firstWhere((r) => r['exam_id'] == examId && r['subject_id'] == sid, orElse: () => {'question_count': 40})['question_count'] as num)
            .toInt();
    final totalQs = examSubjects.where((r) => r['exam_id'] == examId).fold<num>(0, (t, r) => t + (r['question_count'] as num));
    // JAMB: 120 minutes for 180 questions → minutes per question. Others: the subject's own minutes.
    final mpq = cfg['total_minutes'] != null && cfg['subjects_per_candidate'] == 4
        ? (cfg['total_minutes'] as num) / 180
        : () {
            final r = examSubjects.where((r) => r['exam_id'] == examId && r['subject_id'] == subjectIds.first).firstOrNull;
            return r != null && r['minutes'] != null ? (r['minutes'] as num) / (r['question_count'] as num) : 1.0;
          }();
    if (totalQs == 0) return _toast('This exam is not ready yet.');

    setState(() => _starting = true);
    try {
      final title = switch (_mode) {
        TestMode.full => 'JAMB UTME mock',
        TestMode.quick => 'Quick test',
        TestMode.topic => 'Topic drill: $_topic',
        _ => subjects.firstWhere((s) => s['id'] == _subjectId)['name'] as String,
      };
      final id = await ref
          .read(testsRepoProvider)
          .start(
            TestRequest(
              mode: _mode,
              examId: examId,
              examCode: widget.examCode,
              subjectIds: subjectIds,
              year: _year,
              topic: _topic,
              timed: _timed,
              title: title,
            ),
            countFor: countFor,
            minutesPerQuestion: mpq.toDouble(),
          );
      ref.invalidate(unfinishedProvider);
      if (mounted) context.pushReplacement('/cbt/$id');
    } on ApiError catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examsProvider).value;
    final subjects = ref.watch(subjectsProvider).value;
    final examSubjects = ref.watch(examSubjectsProvider).value;
    final years = ref.watch(openYearsProvider);
    if (exams == null || subjects == null || examSubjects == null) {
      return Scaffold(appBar: AppBar(), body: const ListSkeleton());
    }
    final exam = exams.firstWhere((e) => e['code'] == widget.examCode, orElse: () => exams.first);
    final examId = exam['id'];
    final available = {
      for (final r in examSubjects)
        if (r['exam_id'] == examId) r['subject_id'],
    };
    final subjectList = subjects.where((s) => available.contains(s['id'])).toList();
    final c = context.c;
    final modes = [
      if (widget.examCode == 'JAMB') (TestMode.full, 'Full JAMB mock', '4 subjects, like the real exam', PhosphorIcons.exam()),
      (TestMode.subject, 'One subject', 'A full paper for one subject', PhosphorIcons.book()),
      (TestMode.year, 'By year', 'Every question from one year', PhosphorIcons.calendarBlank()),
      (TestMode.quick, 'Quick test', '20 questions', PhosphorIcons.lightning()),
      (TestMode.topic, 'Topic drill', 'Focus on one topic', PhosphorIcons.target()),
    ];
    final yearList = (years.value ?? const [])
        .where((y) => y['exam_id'] == examId && (_subjectId == null || y['subject_id'] == _subjectId))
        .map((y) => (year: (y['year'] as num).toInt(), open: y['cbt_open'] == true))
        .fold<Map<int, bool>>({}, (m, y) => m..update(y.year, (o) => o || y.open, ifAbsent: () => y.open));
    final sortedYears = yearList.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: Row(children: [ExamLogo(widget.examCode, size: 32, bare: true), gap3, Text(exam['name'] as String)])),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s8),
        children: [
          Text('Choose a mode', style: context.t.titleMedium),
          gap3,
          for (final (m, t, s, i) in modes) ...[
            _Option(
              selected: _mode == m,
              icon: i,
              title: t,
              subtitle: s,
              onTap: () => setState(() {
                _mode = m;
                if (m == TestMode.full) _year = null;
              }),
            ),
            gap2,
          ],
          if (_mode != TestMode.full) ...[
            gap4,
            Text('Subject', style: context.t.titleMedium),
            gap3,
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                for (final s in subjectList)
                  ChoiceChip(
                    label: Text(s['name'] as String),
                    selected: _subjectId == s['id'],
                    onSelected: (_) => setState(() {
                      _subjectId = (s['id'] as num).toInt();
                      _year = null;
                    }),
                  ),
              ],
            ),
          ],
          if (_mode == TestMode.topic) ...[
            gap4,
            TextField(
              decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g. Logarithms'),
              onChanged: (v) => _topic = v.trim(),
            ),
          ],
          if (_mode == TestMode.subject || _mode == TestMode.year) ...[
            gap4,
            Text('Year', style: context.t.titleMedium),
            gap3,
            if (sortedYears.isEmpty)
              Text(_subjectId == null ? 'Choose a subject to see its years.' : 'No published years yet for this subject.', style: context.t.bodySmall)
            else
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  if (_mode == TestMode.subject)
                    ChoiceChip(label: const Text('Any year'), selected: _year == null, onSelected: (_) => setState(() => _year = null)),
                  for (final y in sortedYears)
                    ChoiceChip(
                      avatar: yearList[y]! ? null : Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 16),
                      label: Text('$y'),
                      selected: _year == y,
                      onSelected: (_) => yearList[y]! ? setState(() => _year = y) : _toast('$y is part of Premium. Premium is coming soon in the app.'),
                    ),
                ],
              ),
          ],
          gap5,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Timed, like the real exam'),
            subtitle: Text(_timed ? 'The test submits itself when time is up' : 'No timer: take your time to learn'),
            value: _timed,
            onChanged: (v) => setState(() => _timed = v),
          ),
          gap5,
          Container(
            padding: const EdgeInsets.all(Space.s3),
            decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Icon(PhosphorIcons.wifiSlash(), color: c.onSecondarySoft, size: 20),
                gap3,
                Expanded(
                  child: Text(
                    'Once a test starts it works offline. If your phone switches off, continue from where you stopped.',
                    style: context.t.bodySmall?.copyWith(color: c.onSecondarySoft),
                  ),
                ),
              ],
            ),
          ),
          gap5,
          FilledButton(
            onPressed: _starting ? null : () => _start(exam, subjects, examSubjects),
            child: _starting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Start test'),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.secondarySoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: selected ? c.secondary : c.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
          child: Row(
            children: [
              Icon(icon, color: selected ? c.secondary : c.textMuted),
              gap4,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.t.labelLarge),
                    Text(subtitle, style: context.t.bodySmall),
                  ],
                ),
              ),
              Icon(selected ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill) : PhosphorIcons.circle(), color: selected ? c.secondary : c.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
}
