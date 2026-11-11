import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../study/study_widgets.dart';

/// A place in the app a student can jump to from search (D-136).
typedef QuickLink = ({String title, String words, IconData icon, String route, Tone tone});

final List<QuickLink> quickLinks = [
  (
    title: 'Start a CBT practice',
    words: 'test cbt exam practice jamb waec neco start mock quick',
    icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
    route: '/test',
    tone: Tone.navy,
  ),
  (
    title: 'Custom exam',
    words: 'custom exam own questions time subjects',
    icon: PhosphorIcons.listChecks(PhosphorIconsStyle.fill),
    route: '/test/custom',
    tone: Tone.navy,
  ),
  (title: 'AI tutor', words: 'ai tutor ask help explain question chat', icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill), route: '/ai', tone: Tone.blue),
  (
    title: 'Past questions',
    words: 'past questions papers years answers study',
    icon: PhosphorIcons.books(PhosphorIconsStyle.fill),
    route: '/study/pq',
    tone: Tone.blue,
  ),
  (
    title: 'Video lessons',
    words: 'videos lessons watch solutions',
    icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
    route: '/study/videos',
    tone: Tone.blue,
  ),
  (title: 'Lesson notes', words: 'notes lesson read', icon: PhosphorIcons.notePencil(PhosphorIconsStyle.fill), route: '/study/notes', tone: Tone.gold),
  (title: 'Novels', words: 'novel literature books summary', icon: PhosphorIcons.bookOpen(PhosphorIconsStyle.fill), route: '/study/novels', tone: Tone.gold),
  (
    title: 'Syllabus and brochure',
    words: 'syllabus brochure documents pdf',
    icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill),
    route: '/study/docs',
    tone: Tone.navy,
  ),
  (
    title: 'Bookmarks',
    words: 'bookmarks saved questions',
    icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
    route: '/study/bookmarks',
    tone: Tone.gold,
  ),
  (title: 'Downloads', words: 'downloads offline saved', icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill), route: '/downloads', tone: Tone.navy),
  (
    title: 'Challenges',
    words: 'challenges compete win prizes weekly',
    icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
    route: '/challenges',
    tone: Tone.gold,
  ),
  (
    title: 'Leaderboard',
    words: 'leaderboard ranking top students',
    icon: PhosphorIcons.ranking(PhosphorIconsStyle.fill),
    route: '/leaderboard',
    tone: Tone.gold,
  ),
  (
    title: 'My results',
    words: 'history results scores past tests',
    icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
    route: '/history',
    tone: Tone.green,
  ),
  (
    title: 'Invite friends',
    words: 'invite friends referral earn share code',
    icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
    route: '/invite',
    tone: Tone.green,
  ),
  (title: 'My XP', words: 'xp points wallet rewards', icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill), route: '/xp', tone: Tone.gold),
  (title: 'My streak', words: 'streak days fire freeze', icon: PhosphorIcons.fire(PhosphorIconsStyle.fill), route: '/streak', tone: Tone.gold),
  (title: 'News', words: 'news updates announcements', icon: PhosphorIcons.newspaper(PhosphorIconsStyle.fill), route: '/news', tone: Tone.navy),
  (title: 'Notifications', words: 'notifications alerts messages', icon: PhosphorIcons.bell(PhosphorIconsStyle.fill), route: '/notifications', tone: Tone.navy),
  (
    title: 'Get Premium',
    words: 'premium upgrade pay plan subscription buy',
    icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
    route: '/checkout',
    tone: Tone.gold,
  ),
  (
    title: 'My subjects',
    words: 'subjects change jamb combination',
    icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.fill),
    route: '/subjects',
    tone: Tone.navy,
  ),
  (
    title: 'Edit profile',
    words: 'profile name photo school state edit',
    icon: PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
    route: '/edit-profile',
    tone: Tone.navy,
  ),
  (
    title: 'Settings',
    words: 'settings dark mode theme data saver sound notifications',
    icon: PhosphorIcons.gearSix(PhosphorIconsStyle.fill),
    route: '/settings',
    tone: Tone.neutral,
  ),
  (
    title: 'Help and support',
    words: 'help support contact whatsapp email problem',
    icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
    route: '/help',
    tone: Tone.neutral,
  ),
  (title: 'Terms and privacy', words: 'terms privacy legal policy', icon: PhosphorIcons.scales(PhosphorIconsStyle.fill), route: '/legal', tone: Tone.neutral),
  (
    title: 'Delete my account',
    words: 'delete account remove close',
    icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
    route: '/delete-account',
    tone: Tone.red,
  ),
];

/// Every word of the query must appear somewhere in [text] (so "physics 2015" finds "Physics … 2015").
bool searchMatch(String query, String text) {
  final t = text.toLowerCase();
  return query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(t.contains);
}

/// One search for the whole app (D-136): pages, subjects, past question papers by year, topics to practise, and
/// lessons, notes, novels and documents. Everything comes from data the app already has (works offline once cached).
class AppSearchScreen extends ConsumerStatefulWidget {
  const AppSearchScreen({super.key});
  @override
  ConsumerState<AppSearchScreen> createState() => _AppSearchScreenState();
}

class _AppSearchScreenState extends ConsumerState<AppSearchScreen> {
  final _q = TextEditingController();
  static const _kinds = ['video_solution', 'lesson', 'note', 'novel', 'doc'];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _q.text.trim();
    final ready = q.length >= 2;
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    final exams = ref.watch(examsProvider).value ?? const <Map<String, dynamic>>[];
    final years = ref.watch(openYearsProvider).value ?? const <Map<String, dynamic>>[];
    final topics = ref.watch(topicsProvider).value ?? const <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[for (final k in _kinds) ...?ref.watch(studyCatalogProvider(k)).value];
    String subj(Object? id) => '${subjects.where((s) => s['id'] == id).firstOrNull?['name'] ?? ''}';
    String examCode(Object? id) => '${exams.where((e) => e['id'] == id).firstOrNull?['code'] ?? ''}';

    final links = ready ? quickLinks.where((l) => searchMatch(q, '${l.title} ${l.words}')).take(4).toList() : const <QuickLink>[];
    final subjectHits = ready ? subjects.where((s) => searchMatch(q, '${s['name']}')).take(6).toList() : const <Map<String, dynamic>>[];
    // A paper is "JAMB Physics 2015": found by any of its words, but only when the query names a year or the subject.
    final paperHits = !ready || !RegExp(r'\b(19|20)\d\d\b').hasMatch(q)
        ? const <Map<String, dynamic>>[]
        : years.where((y) => searchMatch(q, '${examCode(y['exam_id'])} ${subj(y['subject_id'])} ${y['year']} past questions paper')).take(12).toList();
    final topicHits = ready ? topics.where((t) => searchMatch(q, '${t['name']} ${subj(t['subject_id'])}')).take(8).toList() : const <Map<String, dynamic>>[];
    final itemHits = ready
        ? items
              .where((i) => searchMatch(q, '${i['title']} ${i['subtitle'] ?? ''} ${i['topic'] ?? ''} ${subj(i['subject_id'])} ${i['year'] ?? ''} ${i['kind']}'))
              .take(30)
              .toList()
        : const <Map<String, dynamic>>[];
    final nothing = links.isEmpty && subjectHits.isEmpty && paperHits.isEmpty && topicHits.isEmpty && itemHits.isEmpty;

    Widget section(String title, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Space.s1, bottom: Space.s2),
                  child: Text(title.toUpperCase(), style: context.ty.over.col(c.textMuted)),
                ),
                ListCard(children: rows),
              ],
            ),
          );

    return Scaffold(
      appBar: TopBar(
        center: Padding(
          padding: const EdgeInsets.only(right: Space.s4),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: context.ty.body,
            decoration: InputDecoration(
              hintText: 'Search subjects, topics, years, notes…',
              border: InputBorder.none,
              hintStyle: context.ty.body.col(c.textSubtle),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () => setState(_q.clear),
                      icon: Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), color: c.textSubtle),
                    ),
            ),
          ),
        ),
      ),
      body: !ready
          ? ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                StateBlock(
                  icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                  tone: Tone.blue,
                  title: 'What are you looking for?',
                  text: 'Try a topic ("logarithms"), a subject and year ("Physics 2015"), a note or a page ("streak").',
                ),
                const Gap(Space.s4),
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in const ['Logarithms', 'Physics 2015', 'Organic chemistry', 'Lesson notes', 'Streak'])
                      AppChip(s, on: false, onTap: () => setState(() => _q.text = s)),
                  ],
                ),
              ],
            )
          : nothing
          ? Center(
              child: StateBlock(
                icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                tone: Tone.neutral,
                title: 'No results',
                text: 'Try another word, or browse past questions by exam, subject and year.',
                action: Btn('Browse past questions', kind: BtnKind.outline, onPressed: () => context.push('/study/pq')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                section('Pages', [
                  for (final l in links)
                    ListRow(
                      lead: IconTile(l.icon, tone: l.tone),
                      title: l.title,
                      onTap: () => context.push(l.route),
                    ),
                ]),
                section('Past question papers', [
                  for (final y in paperHits)
                    ListRow(
                      lead: ExamLogo(examCode(y['exam_id']), px: 40),
                      title: '${subj(y['subject_id'])} ${y['year']}',
                      caption: '${examCode(y['exam_id'])} past questions with answers',
                      trailing: y['pq_open'] == true ? null : const PremiumPill(),
                      onTap: () => context.push('/study/pq/${y['exam_id']}/${y['subject_id']}/${y['year']}'),
                    ),
                ]),
                section('Subjects', [
                  for (final s in subjectHits)
                    ListRow(
                      icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
                      title: '${s['name']}',
                      caption: 'Past questions, by year',
                      onTap: () => context.push('/study/pq?subject=${s['id']}'),
                    ),
                ]),
                section('Practise a topic', [
                  for (final t in topicHits)
                    ListRow(
                      lead: IconTile(PhosphorIcons.target(PhosphorIconsStyle.fill), tone: Tone.green),
                      title: '${t['name']}',
                      caption: '${subj(t['subject_id'])} · topic drill',
                      onTap: () =>
                          context.push('/test/setup?exam=JAMB&mode=topic&subject=${t['subject_id']}&topic=${Uri.encodeQueryComponent('${t['name']}')}'),
                    ),
                ]),
                section('Lessons and notes', [
                  for (final i in itemHits)
                    ListRow(
                      lead: IconTile(kindIcon(i['kind'] as String), tone: i['kind'] == 'note' ? Tone.gold : Tone.blue),
                      title: plainTitle(i['title']),
                      caption: [subj(i['subject_id']), i['subtitle'] ?? ''].where((x) => '$x'.isNotEmpty).join(' · '),
                      trailing: i['locked'] == true ? const PremiumPill() : null,
                      onTap: () => openStudyItem(context, i),
                    ),
                ]),
              ],
            ),
    );
  }
}
