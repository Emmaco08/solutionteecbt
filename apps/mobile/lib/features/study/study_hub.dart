import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../core/tab_scroll.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../careers/careers.dart';
import '../premium/paywall.dart';
import 'study_widgets.dart';
import '../classes/classes.dart';
import '../tutor/tutor.dart';
import '../games/games.dart';
import '../community/community.dart';
import '../../desktop/desktop_frame.dart';

/// Default sections when app_settings.study_sections has not loaded (same as the seeded setting).
const _defaultSections = [
  {'key': 'pq', 'icon': 'exam', 'tone': 'navy', 'title': 'Past questions', 'subtitle': 'Study mode with answers', 'enabled': true},
  {'key': 'video_solution', 'icon': 'playCircle', 'tone': 'blue', 'title': 'Video solutions', 'subtitle': 'Watch each answer', 'enabled': true},
  {'key': 'lesson', 'icon': 'chalkboardTeacher', 'tone': 'green', 'title': 'Topic lessons', 'subtitle': 'By syllabus topic', 'enabled': true},
  {'key': 'note', 'icon': 'note', 'tone': 'gold', 'title': 'Lesson notes', 'subtitle': 'Read, with formulas', 'enabled': true},
  {'key': 'novel', 'icon': 'books', 'tone': 'red', 'title': 'Novels', 'subtitle': 'JAMB literature texts', 'enabled': true},
  {'key': 'doc', 'icon': 'filePdf', 'tone': 'navy', 'title': 'Syllabus & brochure', 'subtitle': 'JAMB, WAEC, NECO', 'enabled': true},
];

String sectionPath(String key) => switch (key) {
  'pq' => '/study/pq',
  'video_solution' => '/study/videos?kind=video_solution',
  'lesson' => '/study/videos?kind=lesson',
  'note' => '/study/notes',
  'novel' => '/study/novels',
  _ => '/study/docs',
};

/// Study hub (prototype `study`): search, section tiles from the admin, Continue learning, Bookmarks.
class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});
  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  int? _subject;

  Future<void> _refresh() async {
    ref.invalidate(myPlanProvider);
    ref.invalidate(accessRulesProvider);
    ref.invalidate(appSettingsProvider);
    ref.invalidate(studyProgressProvider);
    ref.invalidate(bookmarksProvider);
    ref.invalidate(contentKindsProvider);
    ref.invalidate(careersProvider);
    ref.invalidate(classesProvider);
    ref.invalidate(tutorProvider);
    await ref.read(studyProgressProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final raw = ref.watch(appSettingsProvider).value?['study_sections'];
    final kinds = ref.watch(contentKindsProvider).value ?? const {};
    final premium = ref.watch(myPlanProvider).value?['tier'] == 'premium';
    final sections = [
      for (final s in (raw is List ? raw : _defaultSections))
        if ((s as Map)['enabled'] != false) Map<String, dynamic>.from(s),
    ];
    final syllabus = myRules(ref)['syllabus'];
    final progress = ref.watch(studyProgressProvider).value ?? const [];
    final shown = [
      for (final p in progress)
        if (_subject == null || (p['position'] as Map?)?['subject_id'] == _subject) p,
    ];
    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];

    return Scaffold(
      appBar: TopBar(
        showBack: false,
        center: Padding(
          padding: const EdgeInsets.only(left: Space.s3),
          child: Text('Study', style: context.ty.h2),
        ),
        actions: [
          IconBtn(PhosphorIcons.magnifyingGlass(), label: 'Search', onPressed: () => context.push('/study/search')),
          IconBtn(
            PhosphorIcons.downloadSimple(),
            label: 'Downloads',
            onPressed: () => featureOn(ref, 'offline') ? context.push('/downloads') : showPaywall(context, reason: 'offline'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: ref.watch(tabScrollProvider(1)),
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
          children: [
            const AdBanner(screen: 'study'),
            _SearchField(onTap: () => context.push('/study/search')),
            const Gap(Space.s6),
            GridView.count(
              crossAxisCount: gridCols(context, 2),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.s3,
              crossAxisSpacing: Space.s3,
              childAspectRatio: wideLayout(context) ? 1.6 : 1.08,
              children: [
                for (final (i, s) in sections.indexed)
                  Builder(
                    builder: (context) {
                      final key = s['key'] as String;
                      final feature = studyFeature[key];
                      // Videos and documents are always open to browse (owner, D-057): every student sees the whole
                      // list, and each Premium item carries its own lock. Notes and novels lock as a section.
                      const browse = {'doc', 'video_solution', 'lesson'};
                      // The admin's rule for the whole box (How content opens): Premium only locks it for free students;
                      // watch videos / pay per item / free open it (each item keeps its own lock and offer).
                      final mode = '${kinds[key] ?? 'default'}';
                      final locked = mode == 'premium'
                          ? !premium
                          : const {'free', 'ads', 'pay'}.contains(mode)
                          ? false
                          : feature != null && !browse.contains(key) && !featureOn(ref, feature);
                      final caption = key == 'doc' && syllabus != null && syllabus != 'all' ? '$syllabus free on your plan' : '${s['subtitle'] ?? ''}';
                      final tile = StudyTile(
                        icon: sectionIcon('${s['icon']}'),
                        tone: toneOf(s['tone'] as String?),
                        title: '${s['title']}',
                        caption: caption,
                        locked: locked,
                        onTap: () {
                          if (locked) {
                            showPaywall(context, reason: key);
                          } else {
                            context.push(sectionPath(key));
                            Ads.instance.breakPoint(ref, 'section'); // ads level: "opening a Study section"
                          }
                        },
                      );
                      return rm ? tile : tile.animate().fadeIn(delay: (40 * i).ms, duration: Motion.base).slideY(begin: .08, end: 0, curve: Curves.easeOut);
                    },
                  ),
              ],
            ),
            const Gap(Space.s4),
            const CareerCard(),
            const Gap(Space.s3),
            const NextClassCard(),
            const Gap(Space.s3),
            const TutorCard(),
            const Gap(Space.s3),
            const GamesCard(),
            const Gap(Space.s3),
            const CommunityCard(),
            const Gap(Space.s6),
            const SectTitle('Continue learning'),
            if (progress.isNotEmpty) ...[
              SubjectChips(
                subjectIds: subjectsIn(ref, [for (final p in progress) Map<String, dynamic>.from((p['position'] as Map?) ?? const {})]),
                value: _subject,
                onChanged: (v) => setState(() => _subject = v),
              ),
              const Gap(Space.s3),
            ],
            ListCard(
              children: shown.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(Space.s5),
                        child: Column(
                          children: [
                            Text('Nothing here yet', style: context.ty.body.bold),
                            const Gap(Space.s1),
                            Text(
                              'Open a note, video or novel and it shows here so you can pick up where you stopped.',
                              textAlign: TextAlign.center,
                              style: context.ty.cap.col(c.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ]
                  : [
                      for (final p in shown.take(5))
                        Builder(
                          builder: (context) {
                            final pos = Map<String, dynamic>.from((p['position'] as Map?) ?? const {});
                            final kind = '${pos['kind'] ?? 'note'}';
                            final pct = ((p['progress'] as num?) ?? 0).toDouble();
                            final video = kind == 'video_solution' || kind == 'lesson';
                            return ListRow(
                              lead: IconTile(kindIcon(kind), tone: video ? Tone.blue : Tone.navy),
                              title: plainTitle(pos['title']),
                              caption: video
                                  ? '${kind == 'lesson' ? 'Topic lesson' : 'Video solution'} · ${(pct * 100).round()}% watched'
                                  : '${subjectName(ref, pos['subject_id'])} · ${(pct * 100).round()}%',
                              trailing: video ? null : SizedBox(width: 56, child: ProgressBar(pct, height: 6)),
                              onTap: () => context.push(studyPath(kind, p['item_id'] as String)),
                            );
                          },
                        ),
                    ],
            ),
            const Gap(Space.s6),
            SectTitle('Bookmarks', action: 'View all', onAction: () => context.push('/study/bookmarks')),
            ListCard(
              children: bookmarks.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(Space.s5),
                        child: Text(
                          'Tap the bookmark icon on a question, note or video to keep it here.',
                          textAlign: TextAlign.center,
                          style: context.ty.cap.col(c.textMuted),
                        ),
                      ),
                    ]
                  : [for (final b in bookmarks.take(3)) BookmarkRow(b: b)],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.search-field`: looks like an input, opens search.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Search questions, topics, notes',
    child: Pressable(
      onTap: onTap,
      scale: .99,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: context.c.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.magnifyingGlass(), size: 20, color: context.c.textSubtle),
            const SizedBox(width: 10),
            Text('Search questions, topics, notes', style: context.ty.body.col(context.c.textSubtle)),
          ],
        ),
      ),
    ),
  );
}

/// What a bookmark points at. Questions: ref = "exam/subject/year/questionId"; items: ref = "kind:id".
({String path, IconData icon, String caption}) bookmarkTarget(Map<String, dynamic> b) {
  final r = '${b['ref']}';
  if (b['kind'] == 'question') {
    final p = r.split('/');
    return (
      path: p.length == 4 ? '/study/pq/${p[0]}/${p[1]}/${p[2]}?q=${p[3]}' : '/study/pq',
      icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
      caption: 'Past question',
    );
  }
  final i = r.indexOf(':');
  final kind = i < 0 ? 'note' : r.substring(0, i);
  final id = i < 0 ? r : r.substring(i + 1);
  return (
    path: studyPath(kind, id),
    icon: kindIcon(kind),
    caption: switch (kind) {
      'video_solution' => 'Video solution',
      'lesson' => 'Topic lesson',
      'novel' => 'Novel',
      'doc' => 'Document',
      _ => 'Lesson note',
    },
  );
}

class BookmarkRow extends ConsumerWidget {
  const BookmarkRow({super.key, required this.b, this.removable = false});
  final Map<String, dynamic> b;
  final bool removable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = bookmarkTarget(b);
    return ListRow(
      lead: IconTile(t.icon, tone: Tone.blue),
      title: plainTitle(b['label']),
      caption: t.caption,
      onTap: () => context.push(t.path),
      trailing: removable
          ? IconBtn(
              PhosphorIcons.x(),
              label: 'Remove bookmark',
              onPressed: () => ref.read(studyRepoProvider).removeBookmark(b['kind'] as String, b['ref'] as String),
            )
          : null,
    );
  }
}

/// Bookmarks (prototype `bookmarks`): Questions · Notes · Videos · Other.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});
  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String _tab = 'Questions';

  static String _tabOf(Map<String, dynamic> b) {
    if (b['kind'] == 'question') return 'Questions';
    final r = '${b['ref']}';
    if (r.startsWith('note:')) return 'Notes';
    if (r.startsWith('video_solution:') || r.startsWith('lesson:')) return 'Videos';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bookmarksProvider);
    final list = all.value ?? const [];
    const tabs = ['Questions', 'Notes', 'Videos', 'Other'];
    final shown = [
      for (final b in list)
        if (_tabOf(b) == _tab) b,
    ];
    return Scaffold(
      appBar: const TopBar(title: 'Bookmarks'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, 10),
            child: Seg<String>(
              value: _tab,
              items: [for (final t in tabs) (t, '$t ${list.where((b) => _tabOf(b) == t).length}')],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          const AdBanner(screen: 'bookmarks'),
          Expanded(
            child: all.isLoading && list.isEmpty
                ? const ListSkeleton()
                : shown.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: StateBlock(
                        icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
                        tone: Tone.blue,
                        title: 'No ${_tab.toLowerCase()} saved yet',
                        text:
                            'Tap the bookmark icon on any ${_tab == 'Videos'
                                ? 'video'
                                : _tab == 'Notes'
                                ? 'note'
                                : _tab == 'Other'
                                ? 'novel or document'
                                : 'question'} to save it here.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s6),
                    children: [
                      ListCard(children: [for (final b in shown) BookmarkRow(b: b, removable: true)]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The admin's rule for each Study box (How content opens): {"note": "ads", "novel": "premium", "pq": "default", …}.
final contentKindsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(myPlanProvider);
  try {
    final j = await ref.read(supabaseProvider).rpc('content_kinds').timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from((j as Map?) ?? const {});
  } catch (_) {
    return const {};
  }
});
