import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/paywall.dart';
import 'study_player.dart';
import 'study_widgets.dart';

/// Video solutions or topic lessons (prototype `videos`).
class VideoListScreen extends ConsumerStatefulWidget {
  const VideoListScreen({super.key, required this.kind});
  final String kind; // video_solution | lesson
  @override
  ConsumerState<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends ConsumerState<VideoListScreen> {
  int? _subject;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studyCatalogProvider(widget.kind));
    final all = async.value ?? const [];
    final shown = [
      for (final v in all)
        if (_subject == null || v['subject_id'] == _subject) v,
    ];
    final saver = ref.watch(settingsProvider).dataSaver;
    final rm = context.reduceMotion;
    final lessons = widget.kind == 'lesson';
    return Scaffold(
      appBar: TopBar(title: lessons ? 'Topic lessons' : 'Video solutions'),
      body: async.hasError && all.isEmpty
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(studyCatalogProvider(widget.kind)))
          : async.isLoading && all.isEmpty
          ? const ListSkeleton()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(studyCatalogProvider(widget.kind).future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
                children: [
                  if (widget.kind == 'video') const AdBanner(screen: 'videos'),
                  SubjectChips(subjectIds: subjectsIn(ref, all), value: _subject, onChanged: (v) => setState(() => _subject = v), allLabel: 'All subjects'),
                  if (saver) ...[
                    const Gap(Space.s4),
                    InfoBanner(
                      kind: BannerKind.warn,
                      icon: PhosphorIcons.cellSignalLow(PhosphorIconsStyle.fill),
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Data saver is on. ',
                              style: TextStyle(fontWeight: kBold),
                            ),
                            TextSpan(text: 'Videos play in low quality (360p).'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Gap(Space.s4),
                  if (shown.isEmpty)
                    StateBlock(
                      icon: kindIcon(widget.kind),
                      tone: Tone.blue,
                      title: lessons ? 'No lessons yet' : 'No video solutions yet',
                      text: 'Our teachers are recording them. Check back soon.',
                    ),
                  for (final (i, v) in shown.indexed) ...[
                    _VideoCard(v: v, index: i).animate(target: rm ? 0 : 1).fadeIn(delay: (40 * i).ms, duration: Motion.base).slideY(begin: .06, end: 0),
                    const Gap(Space.s4),
                  ],
                ],
              ),
            ),
    );
  }
}

class _VideoCard extends ConsumerWidget {
  const _VideoCard({required this.v, required this.index});
  final Map<String, dynamic> v;
  final int index;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = Map<String, dynamic>.from((v['meta'] as Map?) ?? const {});
    final locked = v['locked'] == true;
    final caption = [v['topic'], subjectName(ref, v['subject_id']), v['subtitle']].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => openStudyItem(context, v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VideoThumb(
            index: index,
            subjectIcon: subjectIconFor(ref, v['subject_id']),
            duration: clock(meta['duration_s'] as num?),
            locked: locked,
            coverKey: meta['cover'] as String?,
            itemId: v['id'] as String,
            hd: meta['hd'] == true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plainTitle(v['title']), style: context.ty.sm.bold),
                if (caption.isNotEmpty) Text(caption, style: context.ty.cap.col(context.c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Video player screen (prototype `video`). The file link comes from the website after a plan check; Premium
/// videos block screenshots and screen recording while open. Player: study_player.dart.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  StudyPlayer? _player;
  Map<String, dynamic>? _item;
  Object? _error;
  bool _secured = false;
  Timer? _saver;
  late final StudyRepo _repo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => Ads.instance.prepareBreak(ref)); // a break ad after the video, if the level allows
    _repo = ref.read(studyRepoProvider);
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final item = await ref.read(studyItemProvider(widget.id).future);
      if (!mounted) return;
      if (item['is_free'] != true && !_secured) {
        _secured = true;
        await SecureScreen.on();
      }
      setState(() => _item = item);
      final files = Map<String, dynamic>.from((item['files'] as Map?) ?? const {});
      if (files['360'] != true) return;
      final pos = Map<String, dynamic>.from(firstOr(ref.read(studyProgressProvider).value, (p) => p['item_id'] == widget.id)['position'] as Map? ?? const {});
      final player = StudyPlayer(itemId: widget.id, repo: _repo, hasHd: files['720'] == true, dataSaver: ref.read(settingsProvider).dataSaver);
      player.message.addListener(() {
        final m = player.message.value;
        if (m != null && mounted) toast(context, m, icon: PhosphorIcons.cellSignalLow(PhosphorIconsStyle.fill));
      });
      setState(() => _player = player);
      await player.start(at: Duration(seconds: (pos['seconds'] as num?)?.toInt() ?? 0));
      _saver = Timer.periodic(const Duration(seconds: 15), (_) => _save());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _save() {
    final c = _player?.ctl, item = _item;
    if (c == null || item == null || !c.value.isInitialized) return;
    final d = c.value.duration.inMilliseconds;
    if (d <= 0) return;
    _repo.saveProgress(item, c.value.position.inMilliseconds / d, position: {'seconds': c.value.position.inSeconds});
  }

  @override
  void dispose() {
    _save();
    _saver?.cancel();
    _player?.dispose();
    if (_secured) SecureScreen.off();
    super.dispose();
  }

  bool _breakDone = false;

  @override
  void deactivate() {
    if (!_breakDone) {
      _breakDone = true;
      Ads.instance.breakPoint(ref, 'video');
    }
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final item = _item;
    final err = _error;
    final locked = err is ApiError && err.status == 402;
    final kind = '${item?['kind'] ?? 'video_solution'}';
    final lesson = kind == 'lesson';
    final meta = Map<String, dynamic>.from((firstOr(ref.watch(studyCatalogProvider(kind)).value, (v) => v['id'] == widget.id)['meta'] as Map?) ?? const {});
    final hasFile = (item?['files'] as Map?)?['360'] == true;
    final thumb = VideoThumb(
      index: 0,
      subjectIcon: subjectIconFor(ref, item?['subject_id']),
      radius: 0,
      big: true,
      coverKey: meta['cover'] as String?,
      itemId: widget.id,
      showPlay: !hasFile ? false : _player == null,
    );
    return Scaffold(
      appBar: TopBar(
        title: lesson ? 'Topic lesson' : 'Video solution',
        actions: [if (item != null) BookmarkButton(kind: 'item', refId: '$kind:${widget.id}', label: '${item['title']}')],
      ),
      body: locked
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'This video is for Premium',
                  text: 'Go Premium to watch every video solution and lesson, with every past-question year.',
                  action: Btn(
                    'See Premium plans',
                    kind: BtnKind.accent,
                    leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                    onPressed: () => showPaywall(context, reason: 'video_solution'),
                  ),
                ),
              ),
            )
          : err != null
          ? StateView.error(err, onRetry: _start)
          : item == null
          ? const ListSkeleton(items: 4)
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _player == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            thumb,
                            if (!hasFile)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xC706132B), borderRadius: BorderRadius.circular(99)),
                                  child: Text('The video has not been added yet', style: context.ty.cap.bold.col(Colors.white)),
                                ),
                              ),
                          ],
                        )
                      : StudyPlayerView(player: _player!, title: plainTitle(item['title']), placeholder: thumb),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(plainTitle(item['title']), style: context.ty.h2),
                      const Gap(Space.s2),
                      Text(
                        [
                          subjectName(ref, item['subject_id']),
                          item['subtitle'],
                          clock(((item['data'] as Map?)?['duration_s']) as num?),
                        ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                        style: context.ty.sm.col(c.textMuted),
                      ),
                      if (_player != null) ...[
                        const Gap(Space.s3),
                        Text(
                          'Double-tap the left or right side to go back or forward 10 seconds. Hold the video for 2× speed.',
                          style: context.ty.cap.col(c.textSubtle),
                        ),
                      ],
                      if (item['question_id'] != null) ...[const Gap(Space.s4), _QuestionCard(questionId: item['question_id'] as String)],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The question a video solution explains, when that paper is already on the phone.
class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({required this.questionId});
  final String questionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    return FutureBuilder(
      future: (db.select(db.cachedQuestions)..where((q) => q.id.equals(questionId))).getSingleOrNull(),
      builder: (context, snap) {
        final q = snap.data;
        if (q == null) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The question', style: context.ty.sm.bold),
              const Gap(Space.s2),
              MathText(q.body, style: context.ty.body.copyWith(height: 24 / 15)),
            ],
          ),
        );
      },
    );
  }
}
