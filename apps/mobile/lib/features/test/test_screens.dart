import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/subject_icons.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../cbt/exam_clock.dart';
import '../home/home_screen.dart';
import '../setup/setup_screen.dart';
import '../premium/paywall.dart';
import 'leaderboard_screen.dart';

/// Test tab (prototype: test): navy "Full JAMB simulation" hero, practice modes, other exams, offline note.
class TestHubScreen extends ConsumerWidget {
  const TestHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final exams = ref.watch(examsProvider).value ?? const [];
    final open = ref.watch(openYearsProvider).value;
    final rm = context.reduceMotion;

    Widget modeCard(IconData ic, Tone tone, String title, String sub, VoidCallback onTap, {Widget? trailing}) => AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTile(ic, tone: tone, size: 44, radius: 12, iconSize: 22),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.ty.body.bold),
                Text(sub, style: context.ty.cap.col(c.textMuted)),
              ],
            ),
          ),
          trailing ?? Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );

    ({int open, int all}) yearsFor(String code) {
      final id = exams.where((e) => e['code'] == code).map((e) => e['id']).firstOrNull;
      final mine = (open ?? const []).where((y) => y['exam_id'] == id);
      return (
        open: {
          for (final y in mine)
            if (y['cbt_open'] == true) y['year'],
        }.length,
        all: {for (final y in mine) y['year']}.length,
      );
    }

    final sections = <Widget>[
      // Navy hero
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          color: Palette.navy900,
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const ExamLogo('JAMB', size: LogoSize.bare),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full JAMB simulation', style: context.ty.body.bold.col(const Color(0xFFF4F7FC))),
                        Text('English + 3 subjects · 180 questions · 2 hours', style: context.ty.cap.col(const Color(0xFFAFC0DD))),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(Space.s3),
              Btn('Start full exam', kind: BtnKind.accent, block: true, onPressed: () => context.push('/test/setup?exam=JAMB&mode=full')),
            ],
          ),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectTitle('Practice modes'),
          modeCard(
            PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
            Tone.navy,
            'Single subject',
            'One subject, timed like the real paper',
            () => context.push('/test/setup?exam=JAMB&mode=subject'),
          ),
          const Gap(Space.s2),
          modeCard(
            PhosphorIcons.target(PhosphorIconsStyle.fill),
            Tone.blue,
            'Topic drill',
            'Practise your weak topics only',
            () => context.push('/test/setup?exam=JAMB&mode=topic'),
          ),
          const Gap(Space.s2),
          modeCard(
            PhosphorIcons.lightning(PhosphorIconsStyle.fill),
            Tone.gold,
            'Quick test',
            '20 questions · 15 minutes',
            () => context.push('/test/setup?exam=JAMB&mode=quick'),
          ),
          const Gap(Space.s2),
          modeCard(
            PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
            Tone.green,
            'Practice by year',
            'Pick an exam year and go',
            () => context.push('/test/setup?exam=JAMB&mode=subject'),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectTitle('Other exams'),
          Row(
            children: [
              for (final b in const ['WAEC', 'NECO']) ...[
                if (b == 'NECO') const Gap(Space.s3),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final y = yearsFor(b);
                      final locked = y.all > 0 && y.open == 0;
                      return AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                        onTap: locked ? () => showPaywall(context, reason: b) : () => context.push('/test/setup?exam=$b'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExamLogo(b),
                            const Gap(Space.s3),
                            Text(b, style: context.ty.sm.bold),
                            const Gap(Space.s3),
                            locked
                                ? Pill('Premium', kind: BadgeKind.neutral, icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill))
                                : y.all == 0
                                ? const Pill('Coming soon', kind: BadgeKind.neutral)
                                : y.open == y.all
                                ? Pill('All years', kind: BadgeKind.success, icon: PhosphorIcons.lockSimpleOpen(PhosphorIconsStyle.fill))
                                : Pill('${y.open} year${y.open == 1 ? '' : 's'} free', icon: PhosphorIcons.lockSimpleOpen(PhosphorIconsStyle.fill)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      if (ref.watch(leaderboardOnProvider).value == true) const LeaderboardEntry(),
      modeCard(
        PhosphorIcons.cloudArrowDown(PhosphorIconsStyle.fill),
        Tone.navy,
        'Practise without data',
        'Tests you start stay on your phone. Finish them offline.',
        () => toast(context, 'Start a test once with internet. You can then finish it offline.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill)),
        trailing: const SizedBox(),
      ),
    ];

    return Scaffold(
      appBar: TopBar(
        showBack: false,
        center: Padding(
          padding: const EdgeInsets.only(left: Space.s3),
          child: Text('Test', style: context.ty.h2),
        ),
        actions: [IconBtn(PhosphorIcons.clockCounterClockwise(), label: 'Test history', onPressed: () => context.push('/history'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const Gap(Space.s6),
            rm ? sections[i] : sections[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .06, curve: Motion.out),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- test setup (prototype: test-setup)
/// Every mode starts a FRESH test. If one is unfinished, the student chooses: start new (the old one is
/// submitted as it is, so its score counts) or continue it.
class TestSetupScreen extends ConsumerStatefulWidget {
  const TestSetupScreen({super.key, required this.examCode, this.mode});
  final String examCode;
  final String? mode;
  @override
  ConsumerState<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends ConsumerState<TestSetupScreen> {
  late TestMode _mode;
  int? _subjectId;
  int? _year; // null = mixed (open years)
  final _topics = <String>{};
  int _count = 20;
  bool _timed = true, _starting = false;

  bool get _jamb => widget.examCode == 'JAMB';

  List<(TestMode, String)> get _modes => _jamb
      ? const [(TestMode.full, 'Full exam'), (TestMode.subject, 'Subject'), (TestMode.topic, 'Topic'), (TestMode.quick, 'Quick')]
      : const [(TestMode.subject, 'One subject'), (TestMode.topic, 'Topic')];

  @override
  void initState() {
    super.initState();
    final want = TestMode.values.where((m) => m.name == widget.mode).firstOrNull;
    _mode = _modes.any((m) => m.$1 == want) ? want! : _modes.first.$1;
  }

  String get _help => switch (_mode) {
    TestMode.full => 'All your subjects, timed like the real UTME.',
    TestMode.subject => 'One subject at a time, timed.',
    TestMode.topic => 'Only the topics you pick. Great for weak areas.',
    TestMode.quick => '20 mixed questions in 15 minutes.',
    TestMode.year => '',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final exams = ref.watch(examsProvider).value;
    final subjects = ref.watch(subjectsProvider).value;
    final links = ref.watch(examSubjectsProvider).value;
    final years = ref.watch(openYearsProvider).value;
    final profile = ref.watch(profileProvider).value;
    if (exams == null || subjects == null || links == null) {
      return const Scaffold(appBar: TopBar(), body: ListSkeleton());
    }
    final exam = exams.where((e) => e['code'] == widget.examCode).firstOrNull ?? exams.first;
    final examId = (exam['id'] as num).toInt();
    final cfg = (exam['exam_configs'] as Map?) ?? const {};
    final examLinks = links.where((r) => r['exam_id'] == examId).toList();
    final available = {for (final r in examLinks) r['subject_id']};
    final jambCodes = ((profile?['jamb_subjects'] as List?) ?? const []).cast<String>();
    // JAMB: the student's own subjects (English first); WAEC/NECO: every subject of that exam.
    var subs = subjects.where((s) => available.contains(s['id'])).toList();
    if (_jamb && jambCodes.length == 4) {
      subs = subs.where((s) => jambCodes.contains(s['code'])).toList()..sort((a, b) => a['code'] == 'eng' ? -1 : (b['code'] == 'eng' ? 1 : 0));
    }
    _subjectId ??= subs.length > 1 && _jamb ? (subs[1]['id'] as num).toInt() : (subs.isEmpty ? null : (subs.first['id'] as num).toInt());
    int countFor(int sid) => ((examLinks.where((r) => r['subject_id'] == sid).firstOrNull?['question_count'] as num?) ?? 40).toInt();
    int? minutesFor(int sid) => (examLinks.where((r) => r['subject_id'] == sid).firstOrNull?['minutes'] as num?)?.toInt();
    final totalMins = (cfg['total_minutes'] as num?)?.toInt() ?? 120;

    // Years for the chosen subject (or all subjects for full / quick).
    final yearRows = (years ?? const []).where(
      (y) => y['exam_id'] == examId && (_mode == TestMode.full || _mode == TestMode.quick || y['subject_id'] == _subjectId),
    );
    final openYears = ({
      for (final y in yearRows)
        if (y['cbt_open'] == true) (y['year'] as num).toInt(),
    }.toList()..sort((a, b) => b.compareTo(a)));
    final anyLocked = yearRows.any((y) => y['cbt_open'] != true);
    if (_year != null && !openYears.contains(_year)) _year = null;

    // Summary: questions, time, max score.
    final fullSubs = subs.map((s) => (s['id'] as num).toInt()).toList();
    final (int q, int mins, String max, String maxLabel) = switch (_mode) {
      TestMode.full => (fullSubs.fold(0, (t, s) => t + countFor(s)), totalMins, '400', 'max score'),
      TestMode.quick => (20, 15, '%', 'score shown'),
      TestMode.topic => (_count, _count, '%', 'score shown'),
      _ =>
        _subjectId == null
            ? (0, 0, '%', 'score shown')
            : (countFor(_subjectId!), _jamb ? totalMins ~/ 4 : (minutesFor(_subjectId!) ?? 60), _jamb ? '100' : '%', _jamb ? 'max score' : 'score shown'),
    };
    final subjectTopics = (ref.watch(topicsProvider).value ?? const []).where((t) => t['subject_id'] == _subjectId).map((t) => t['name'] as String).toList();
    final needTopic = _mode == TestMode.topic && _topics.isEmpty;
    final needSubjects = _mode == TestMode.full && jambCodes.length != 4;

    final blocks = <Widget>[
      Row(
        children: [
          ExamLogo(widget.examCode, size: LogoSize.lg),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up your practice', style: context.ty.h2),
                Text(_jamb ? 'Rules come from the JAMB exam config.' : 'Objective paper, like the real exam.', style: context.ty.sm.col(c.textMuted)),
              ],
            ),
          ),
        ],
      ),
      _FieldBlock(
        label: 'Mode',
        help: _help,
        child: Seg<TestMode>(
          value: _mode,
          items: _modes,
          onChanged: (m) => setState(() {
            _mode = m;
            _topics.clear();
          }),
        ),
      ),
      if (_mode == TestMode.full)
        _FieldBlock(
          label: 'Your subjects',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needSubjects)
                InfoBanner(kind: BannerKind.warn, child: const Text('Choose your 4 JAMB subjects first.'))
              else
                ListCard(
                  children: [
                    for (final s in subs)
                      ListRow(
                        icon: subjectIcon(s['code'] as String, PhosphorIconsStyle.fill),
                        title: s['name'] as String,
                        trailing: Text('${countFor((s['id'] as num).toInt())} questions', style: context.ty.cap.tnum.col(c.textMuted)),
                      ),
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Btn('Change subjects', kind: BtnKind.ghost, sm: true, onPressed: () => context.push('/subjects')),
              ),
            ],
          ),
        ),
      if (_mode == TestMode.subject || _mode == TestMode.topic)
        _FieldBlock(
          label: 'Subject',
          child: Column(
            children: [
              for (final s in subs) ...[
                SubjTile(
                  on: _subjectId == s['id'],
                  lead: Icon(subjectIcon(s['code'] as String), size: 20),
                  child: Text(s['name'] as String, style: context.ty.label.bold),
                  onTap: () => setState(() {
                    _subjectId = (s['id'] as num).toInt();
                    _topics.clear();
                  }),
                ),
                const Gap(Space.s2),
              ],
            ],
          ),
        ),
      if (_mode == TestMode.topic) ...[
        _FieldBlock(
          label: 'Topics',
          labelNote: ' (pick one or more)',
          child: subjectTopics.isEmpty
              ? Text('Topics for this subject are coming soon.', style: context.ty.sm.col(c.textMuted))
              : Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  children: [
                    for (final t in subjectTopics)
                      AppChip(t, on: _topics.contains(t), onTap: () => setState(() => _topics.contains(t) ? _topics.remove(t) : _topics.add(t))),
                  ],
                ),
        ),
        _FieldBlock(
          label: 'Number of questions',
          child: Seg<int>(value: _count, items: const [(10, '10'), (20, '20'), (30, '30')], onChanged: (n) => setState(() => _count = n)),
        ),
      ],
      if (_mode != TestMode.quick)
        _FieldBlock(
          label: 'Year',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                AppChip(anyLocked ? 'Mixed (your free years)' : 'Mixed (all years)', on: _year == null, onTap: () => setState(() => _year = null)),
                for (final y in openYears) ...[const Gap(Space.s2), AppChip('$y', on: _year == y, onTap: () => setState(() => _year = y))],
                if (anyLocked) ...[
                  const Gap(Space.s2),
                  AppChip(
                    'More years',
                    on: false,
                    icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                    onTap: () => showPaywall(context, reason: 'years'),
                  ),
                ],
              ],
            ),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timed', style: context.ty.sm.bold),
                Text(_timed ? 'The clock runs like the real exam.' : 'No clock. Take your time.', style: context.ty.cap.col(c.textMuted)),
              ],
            ),
          ),
          AppSwitch(value: _timed, onChanged: (v) => setState(() => _timed = v)),
        ],
      ),
      AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Sum(value: '$q', label: 'questions'),
            _Sum(
              value: !_timed ? '–' : (mins >= 60 ? '${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}' : '$mins'),
              label: !_timed ? 'untimed' : (mins >= 60 ? 'hours' : 'minutes'),
            ),
            _Sum(value: max, label: maxLabel),
          ],
        ),
      ),
      InfoBanner(
        icon: PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.fill),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'This starts a '),
              TextSpan(text: 'new', style: context.ty.sm.bold.col(c.onSecondarySoft)),
              const TextSpan(text: ' test. To finish an old one, use '),
              TextSpan(text: 'Continue your test', style: context.ty.sm.bold.col(c.onSecondarySoft)),
              const TextSpan(text: ' on Home.'),
            ],
          ),
        ),
      ),
      Row(
        children: [
          Icon(PhosphorIcons.wifiHigh(PhosphorIconsStyle.fill), size: 14, color: c.textMuted),
          const SizedBox(width: 4),
          Expanded(child: Text('Needs internet to download the questions. You can finish offline.', style: context.ty.cap.col(c.textMuted))),
        ],
      ),
    ];

    final startLabel = needTopic
        ? 'Pick at least one topic'
        : switch (_mode) {
            TestMode.full => 'Start full exam',
            TestMode.topic => 'Start topic drill',
            TestMode.quick => 'Start quick test',
            _ => 'Start subject practice',
          };
    final rm = context.reduceMotion;

    return Scaffold(
      appBar: TopBar(
        title:
            '${widget.examCode} ${_jamb
                ? 'UTME'
                : widget.examCode == 'WAEC'
                ? 'WASSCE'
                : 'SSCE'} practice',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const Gap(Space.s5),
            rm ? blocks[i] : blocks[i].animate(delay: Motion.stagger * i.clamp(0, 8)).fadeIn(duration: Motion.slow).slideY(begin: .06, curve: Motion.out),
          ],
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Btn(
          startLabel,
          block: true,
          loading: _starting,
          onPressed: needTopic || needSubjects || q == 0 ? null : () => _start(examId, cfg, subs, countFor, minutesFor, totalMins),
        ),
      ),
    );
  }

  Future<void> _start(int examId, Map cfg, List<Map<String, dynamic>> subs, int Function(int) countFor, int? Function(int) minutesFor, int totalMins) async {
    final db = ref.read(dbProvider);
    final unfinished = await db.unfinishedAttempt();
    if (unfinished != null && mounted) {
      final answers = await db.answersFor(unfinished.id);
      final done = answers.where((a) => a.choice != null).length;
      if (done > 0 && mounted) {
        final total = (jsonDecode(unfinished.questionIdsJson) as List).length;
        final left = unfinished.limitSeconds == 0 ? null : Duration(seconds: unfinished.limitSeconds) - Duration(milliseconds: unfinished.usedMs);
        final title = ((jsonDecode(unfinished.configJson) as Map)['title'] as String?) ?? unfinished.examCode;
        final choice = await showAppDialog<String>(
          context,
          icon: PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill),
          tone: Tone.blue,
          title: 'You have an unfinished test',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: context.ty.sm.col(context.c.textMuted),
                  children: [
                    TextSpan(text: title, style: context.ty.sm.bold.col(context.c.text)),
                    TextSpan(text: ': $done of $total answered${left == null ? '' : ', ${ExamClock.format(left)} left'}.'),
                  ],
                ),
              ),
              const Gap(Space.s3),
              Text('Starting a new test submits the unfinished one as it is, so its score still counts.', style: context.ty.sm.col(context.c.textMuted)),
            ],
          ),
          actions: [
            Builder(builder: (ctx) => Btn('Start new test', block: true, onPressed: () => Navigator.pop(ctx, 'new'))),
            Builder(
              builder: (ctx) => Btn('Continue unfinished test', kind: BtnKind.outline, block: true, onPressed: () => Navigator.pop(ctx, 'old')),
            ),
            Builder(
              builder: (ctx) => Btn('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx)),
            ),
          ],
        );
        if (choice == null || !mounted) return;
        if (choice == 'old') {
          context.pushReplacement('/cbt/${unfinished.id}');
          return;
        }
      }
    }

    final subjectIds = switch (_mode) {
      TestMode.full || TestMode.quick => [for (final s in subs) (s['id'] as num).toInt()],
      _ => [_subjectId!],
    };
    final subjectName = subs.where((s) => s['id'] == _subjectId).map((s) => s['name'] as String).firstOrNull ?? '';
    final title = switch (_mode) {
      TestMode.full => 'JAMB UTME Mock',
      TestMode.quick => 'Quick test',
      TestMode.topic => 'Topic drill · ${_topics.join(', ')}',
      _ => '${widget.examCode} $subjectName${_year == null ? '' : ' $_year'}',
    };
    // Minutes per question: JAMB 120 min for 180 questions; WAEC/NECO the subject's own minutes.
    final mpq = _jamb ? totalMins / 180 : (minutesFor(subjectIds.first) ?? 60) / countFor(subjectIds.first);

    setState(() => _starting = true);
    try {
      final id = await ref
          .read(testsRepoProvider)
          .start(
            TestRequest(
              mode: _mode,
              examId: examId,
              examCode: widget.examCode,
              subjectIds: subjectIds,
              year: _year,
              topics: _topics.toList(),
              count: _mode == TestMode.quick ? 20 : _count,
              limitMinutes: switch (_mode) {
                TestMode.quick => 15,
                TestMode.topic => _count,
                TestMode.subject when _jamb => totalMins ~/ 4,
                _ => null,
              },
              timed: _timed,
              title: title,
            ),
            countFor: countFor,
            minutesPerQuestion: mpq.toDouble(),
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

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.child, this.help, this.labelNote});
  final String label;
  final String? help, labelNote;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          style: context.ty.sm.bold,
          children: [
            TextSpan(text: label),
            if (labelNote != null) TextSpan(text: labelNote, style: context.ty.sm.col(context.c.textMuted)),
          ],
        ),
      ),
      const Gap(Space.s2),
      child,
      if (help != null && help!.isNotEmpty) ...[const Gap(Space.s2), Text(help!, style: context.ty.cap.col(context.c.textMuted))],
    ],
  );
}

class _Sum extends StatelessWidget {
  const _Sum({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: context.ty.h2.tnum),
      Text(label, style: context.ty.cap.col(context.c.textMuted)),
    ],
  );
}
