import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/subject_icons.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';

// Careers and JAMB subject combinations (A2, D-137). The admin manages the list (Admin -> Careers); every row is public.

final careersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'careers',
    (s) => s
        .from('careers')
        .select('id, name, field, course, years, summary, skills, universities, earnings, jamb_subjects, jamb_note, olevel, after_school, sort')
        .eq('active', true)
        .order('sort', ascending: true),
    rows,
  ),
);

/// The career the student picked, or null (none picked, or the admin removed it).
final myCareerProvider = Provider<Map<String, dynamic>?>((ref) {
  final id = ref.watch(profileProvider).value?['career_id'];
  if (id == null) return null;
  return ref.watch(careersProvider).value?.where((c) => c['id'] == id).firstOrNull;
});

/// The three JAMB subjects besides English, as codes.
List<String> careerSubjects(Map<String, dynamic> c) => [for (final s in (c['jamb_subjects'] as List? ?? const [])) '$s'];

/// "English, Biology, Chemistry, Physics" (English is always first).
String combination(Map<String, dynamic> c, String Function(String code) name) => ['Use of English', for (final s in careerSubjects(c)) name(s)].join(', ');

/// Every word must match the career's name, course or group (same rule as app search).
bool careerMatch(String query, Map<String, dynamic> c) {
  final t = '${c['name']} ${c['course']} ${c['field']}'.toLowerCase();
  return query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(t.contains);
}

IconData fieldIcon(String? field, [PhosphorIconsStyle s = PhosphorIconsStyle.fill]) => switch ((field ?? '').toLowerCase()) {
  final f when f.contains('health') => PhosphorIcons.flask(s),
  final f when f.contains('engineer') || f.contains('tech') => PhosphorIcons.wrench(s),
  final f when f.contains('agric') || f.contains('science') => PhosphorIcons.plant(s),
  final f when f.contains('business') => PhosphorIcons.chartLineUp(s),
  final f when f.contains('law') || f.contains('social') => PhosphorIcons.scales(s),
  final f when f.contains('art') || f.contains('educ') => PhosphorIcons.bookOpen(s),
  _ => PhosphorIcons.graduationCap(s),
};

Tone fieldTone(String? field) => switch ((field ?? '').toLowerCase()) {
  final f when f.contains('health') => Tone.green,
  final f when f.contains('engineer') || f.contains('tech') => Tone.blue,
  final f when f.contains('business') => Tone.gold,
  final f when f.contains('law') || f.contains('social') => Tone.navy,
  final f when f.contains('art') || f.contains('educ') => Tone.red,
  _ => Tone.green,
};

String Function(String) subjectNamer(WidgetRef ref) {
  final list = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
  final names = {for (final s in list) '${s['code']}': '${s['name']}'};
  return (code) => names[code] ?? code.toUpperCase();
}

/// Saves the student's dream career (null clears it). Returns false when it could not be saved.
Future<bool> saveMyCareer(WidgetRef ref, int? id, {List<String>? jambSubjects}) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final p = ref.read(profileProvider).value;
    final exams = {...((p?['target_exams'] as List?) ?? const []).cast<String>()};
    await Supabase.instance.client
        .from('profiles')
        .update({
          'career_id': id,
          if (jambSubjects != null) 'jamb_subjects': ['eng', ...jambSubjects],
          if (jambSubjects != null) 'target_exams': {...exams, 'JAMB'}.toList(),
        })
        .eq('id', uid);
    ref.invalidate(profileProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// A sheet to pick a career (used by setup's JAMB subjects step). Returns the career, or null.
Future<Map<String, dynamic>?> pickCareer(BuildContext context) => showSheet<Map<String, dynamic>>(
  context,
  builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * .82, child: const _CareerPicker()),
);

class _CareerPicker extends ConsumerStatefulWidget {
  const _CareerPicker();
  @override
  ConsumerState<_CareerPicker> createState() => _CareerPickerState();
}

class _CareerPickerState extends ConsumerState<_CareerPicker> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = subjectNamer(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What do you want to become?', style: context.ty.h3),
          const Gap(Space.s1),
          Text('We will fill in the JAMB subjects for that course.', style: context.ty.sm.col(context.c.textMuted)),
          const Gap(Space.s3),
          _SearchBox(controller: _q, onChanged: () => setState(() {})),
          const Gap(Space.s3),
          Expanded(
            child: asyncView(ref.watch(careersProvider), (list) {
              final shown = list.where((c) => careerMatch(_q.text.trim(), c)).toList();
              if (shown.isEmpty) return const _NoMatch();
              return ListView(
                padding: const EdgeInsets.only(bottom: Space.s6),
                children: [
                  ListCard(
                    children: [
                      for (final c in shown)
                        ListRow(
                          lead: IconTile(fieldIcon(c['field'] as String?), tone: fieldTone(c['field'] as String?)),
                          title: '${c['name']}',
                          caption: combination(c, name),
                          onTap: () => Navigator.of(context).pop(c),
                        ),
                    ],
                  ),
                ],
              );
            }, onRetry: () => ref.invalidate(careersProvider)),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged, this.hint = 'Search: doctor, law, engineer…'});
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: context.ty.body,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: c.textSubtle),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), color: c.textSubtle),
              ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();
  @override
  Widget build(BuildContext context) => StateBlock(
    icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
    tone: Tone.neutral,
    title: 'No career matches',
    text: 'Try another word, like "nurse", "bank" or "engineer".',
  );
}

/// Study tab card: the student's career and its JAMB combination, or an invitation to pick one.
class CareerCard extends ConsumerWidget {
  const CareerCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final mine = ref.watch(myCareerProvider);
    final name = subjectNamer(ref);
    return AppCard(
      onTap: () => context.push(mine == null ? '/careers' : '/careers/${mine['id']}'),
      child: Row(
        children: [
          IconTile(mine == null ? PhosphorIcons.graduationCap(PhosphorIconsStyle.fill) : fieldIcon(mine['field'] as String?), tone: Tone.gold, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mine == null ? 'Careers and subject combinations' : 'My dream career: ${mine['name']}', style: context.ty.body.bold),
                const Gap(2),
                Text(
                  mine == null ? 'Find the JAMB subjects for the course you want.' : 'JAMB: ${combination(mine, name)}',
                  style: context.ty.cap.col(c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
  }
}

/// All careers: my career first, then search and groups (Study -> Careers, Settings -> My dream career).
class CareersScreen extends ConsumerStatefulWidget {
  const CareersScreen({super.key});
  @override
  ConsumerState<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends ConsumerState<CareersScreen> {
  final _q = TextEditingController();
  String? _field;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final name = subjectNamer(ref);
    final mine = ref.watch(myCareerProvider);
    return Scaffold(
      appBar: const TopBar(title: 'Careers'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(careersProvider);
          await ref.read(careersProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
        },
        child: asyncView(ref.watch(careersProvider), (list) {
          if (list.isEmpty) {
            return ListView(
              children: [
                StateBlock(
                  icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
                  title: 'Careers are coming soon',
                  text: 'Check back later for jobs, courses and the JAMB subjects you need.',
                ),
              ],
            );
          }
          final fields = {for (final x in list) '${x['field']}'}.toList();
          final q = _q.text.trim();
          final shown = list.where((x) => (_field == null || x['field'] == _field) && careerMatch(q, x)).toList();
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final x in shown) {
            groups.putIfAbsent('${x['field']}', () => []).add(x);
          }
          var i = 0;
          Widget enter(Widget w) => rm ? w : w.animate().fadeIn(delay: (30 * (i++).clamp(0, 10)).ms, duration: Motion.base).slideY(begin: .06, end: 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            children: [
              if (mine != null) ...[
                const SectTitle('My dream career'),
                ListCard(
                  children: [
                    ListRow(
                      lead: IconTile(fieldIcon(mine['field'] as String?), tone: Tone.gold),
                      title: '${mine['name']}',
                      caption: 'JAMB: ${combination(mine, name)}',
                      onTap: () => context.push('/careers/${mine['id']}'),
                    ),
                  ],
                ),
                const Gap(Space.s5),
              ] else ...[
                InfoBanner(
                  icon: PhosphorIcons.target(PhosphorIconsStyle.fill),
                  child: const Text('Tap a career to see what the job is, the JAMB subjects, the course and where to study. Then make it your dream career.'),
                ),
                const Gap(Space.s4),
              ],
              _SearchBox(controller: _q, onChanged: () => setState(() {}), hint: 'Search careers or courses'),
              const Gap(Space.s3),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppChip('All', on: _field == null, onTap: () => setState(() => _field = null)),
                    for (final f in fields) ...[
                      const Gap(Space.s2),
                      AppChip(f, on: _field == f, icon: fieldIcon(f, PhosphorIconsStyle.regular), onTap: () => setState(() => _field = _field == f ? null : f)),
                    ],
                  ],
                ),
              ),
              const Gap(Space.s4),
              if (shown.isEmpty) const _NoMatch(),
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(left: Space.s1, bottom: Space.s2),
                  child: Text(g.key.toUpperCase(), style: context.ty.over.col(c.textMuted)),
                ),
                enter(
                  ListCard(
                    children: [
                      for (final x in g.value)
                        ListRow(
                          lead: IconTile(fieldIcon(x['field'] as String?), tone: fieldTone(x['field'] as String?)),
                          title: '${x['name']}',
                          caption: combination(x, name),
                          onTap: () => context.push('/careers/${x['id']}'),
                        ),
                    ],
                  ),
                ),
                const Gap(Space.s4),
              ],
              const _BrochureNote(),
            ],
          );
        }, onRetry: () => ref.invalidate(careersProvider)),
      ),
    );
  }
}

class _BrochureNote extends StatelessWidget {
  const _BrochureNote();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: Space.s2),
    child: Text(
      'Each university can ask for slightly different subjects. Always confirm your combination in this year\'s JAMB brochure before you register. Pay is a rough guide only.',
      textAlign: TextAlign.center,
      style: context.ty.cap.col(context.c.textSubtle),
    ),
  );
}

/// One career: the job, the path (secondary, JAMB, university, after school), skills, universities and pay.
class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen> {
  bool _saving = false;

  Future<void> _pick(Map<String, dynamic> career, {required bool setSubjects}) async {
    setState(() => _saving = true);
    final subjects = careerSubjects(career);
    final ok = await saveMyCareer(ref, widget.id, jambSubjects: setSubjects && subjects.length == 3 ? subjects : null);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return toast(context, 'Could not save. Check your internet and try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    toast(
      context,
      setSubjects ? 'Saved. Your JAMB subjects now match ${career['name']}.' : '${career['name']} is now your dream career.',
      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = subjectNamer(ref);
    final async = ref.watch(careersProvider);
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: const TopBar(title: 'Career'),
      body: asyncView(async, (list) {
        final x = list.where((r) => r['id'] == widget.id).firstOrNull;
        if (x == null) {
          return StateBlock(
            icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
            title: 'This career is not available',
            text: 'It may have been removed. Pick another one.',
            action: Btn('See all careers', kind: BtnKind.outline, onPressed: () => context.pushReplacement('/careers')),
          );
        }
        final subjects = careerSubjects(x);
        final mineSubjects = [for (final s in ((profile?['jamb_subjects'] as List?) ?? const [])) '$s']..remove('eng');
        final same = subjects.length == 3 && subjects.toSet().containsAll(mineSubjects) && mineSubjects.length == 3;
        final isMine = profile?['career_id'] == widget.id;
        final skills = [for (final s in (x['skills'] as List? ?? const [])) '$s'];
        final unis = [for (final s in (x['universities'] as List? ?? const [])) '$s'];
        final years = x['years'];
        final steps = <(String, String, IconData)>[
          if ('${x['olevel'] ?? ''}'.isNotEmpty) ('Secondary school', '${x['olevel']}', PhosphorIcons.exam(PhosphorIconsStyle.fill)),
          ('JAMB (UTME)', combination(x, name), PhosphorIcons.listChecks(PhosphorIconsStyle.fill)),
          ('University', '${x['course']}${years == null ? '' : ', about $years years'}.', PhosphorIcons.graduationCap(PhosphorIconsStyle.fill)),
          if ('${x['after_school'] ?? ''}'.isNotEmpty) ('After school', '${x['after_school']}', PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill)),
        ];
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
                children: [
                  Row(
                    children: [
                      IconTile(fieldIcon(x['field'] as String?), tone: fieldTone(x['field'] as String?), size: 56, iconSize: 28, radius: Radii.lg),
                      const Gap(Space.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${x['name']}', style: context.ty.h2),
                            const Gap(2),
                            Text('${x['field']}', style: context.ty.sm.col(c.textMuted)),
                          ],
                        ),
                      ),
                      if (isMine) Pill('My career', kind: BadgeKind.gold, icon: PhosphorIcons.star(PhosphorIconsStyle.fill)),
                    ],
                  ),
                  const Gap(Space.s4),
                  Text('${x['summary']}', style: context.ty.body),
                  const Gap(Space.s6),
                  const SectTitle('JAMB subjects'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Space.s2,
                          runSpacing: Space.s2,
                          children: [
                            for (final code in ['eng', ...subjects])
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                                decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(Radii.md)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(subjectIcon(code), size: 18, color: c.onSecondarySoft),
                                    const Gap(Space.s2),
                                    Text(code == 'eng' ? 'Use of English' : name(code), style: context.ty.sm.bold.col(c.onSecondarySoft)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if ('${x['jamb_note'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s3), Text('${x['jamb_note']}', style: context.ty.cap.col(c.textMuted))],
                      ],
                    ),
                  ),
                  const Gap(Space.s6),
                  const SectTitle('Your path'),
                  AppCard(
                    child: Column(
                      children: [
                        for (final (i, s) in steps.indexed)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  children: [
                                    IconTile(s.$3, tone: Tone.blue, size: 32, iconSize: 16),
                                    if (i < steps.length - 1) Expanded(child: Container(width: 2, color: c.border)),
                                  ],
                                ),
                                const Gap(Space.s3),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? Space.s4 : 0, top: 5),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.$1, style: context.ty.sm.bold),
                                        const Gap(2),
                                        Text(s.$2, style: context.ty.sm.col(c.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (skills.isNotEmpty) ...[
                    const Gap(Space.s6),
                    const SectTitle('Skills that help'),
                    Wrap(
                      spacing: Space.s2,
                      runSpacing: Space.s2,
                      children: [for (final s in skills) Pill(s, kind: BadgeKind.neutral)],
                    ),
                  ],
                  if (unis.isNotEmpty) ...[
                    const Gap(Space.s6),
                    const SectTitle('Where to study'),
                    ListCard(
                      children: [
                        for (final u in unis) ListRow(icon: PhosphorIcons.graduationCap(PhosphorIconsStyle.fill), tone: Tone.navy, title: u, caret: false),
                      ],
                    ),
                    const Gap(Space.s1),
                    Text('Some good choices. Many other universities offer this course too.', style: context.ty.cap.col(c.textSubtle)),
                  ],
                  if ('${x['earnings'] ?? ''}'.isNotEmpty) ...[
                    const Gap(Space.s6),
                    const SectTitle('Pay'),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconTile(PhosphorIcons.money(PhosphorIconsStyle.fill), tone: Tone.green, size: 36, iconSize: 18),
                          const Gap(Space.s3),
                          Expanded(child: Text('${x['earnings']}', style: context.ty.sm)),
                        ],
                      ),
                    ),
                  ],
                  const Gap(Space.s5),
                  const _BrochureNote(),
                ],
              ),
            ),
            FooterCta(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine)
                    Btn(
                      'This is my dream career',
                      block: true,
                      loading: _saving,
                      leading: PhosphorIcons.star(PhosphorIconsStyle.fill),
                      onPressed: _saving ? null : () => _pick(x, setSubjects: false),
                    )
                  else if (!same && subjects.length == 3)
                    Btn('Use these as my JAMB subjects', block: true, loading: _saving, onPressed: _saving ? null : () => _pick(x, setSubjects: true))
                  else
                    Btn('Practise for JAMB', block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => context.push('/test/setup?exam=JAMB')),
                  if (isMine) ...[
                    const Gap(Space.s2),
                    Btn(
                      'Not my dream career any more',
                      kind: BtnKind.ghost,
                      block: true,
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              final ok = await saveMyCareer(ref, null);
                              if (!mounted) return;
                              setState(() => _saving = false);
                              if (!ok) toast(this.context, 'Could not save. Check your internet and try again.');
                            },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }, onRetry: () => ref.invalidate(careersProvider)),
    );
  }
}
