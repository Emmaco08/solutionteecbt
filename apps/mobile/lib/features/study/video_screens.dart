import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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
          VideoThumb(index: index, subjectIcon: subjectIconFor(ref, v['subject_id']), duration: clock(meta['duration_s'] as num?), locked: locked),
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

/// Video player (prototype `video`). The file link comes from the website after a plan check; Premium
/// videos block screenshots and screen recording while open.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _ctl;
  Map<String, dynamic>? _item;
  String? _quality;
  Object? _error;
  bool _loading = false, _secured = false;
  double _speed = 1;
  Timer? _saver;
  late final StudyRepo _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(studyRepoProvider);
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final item = await ref.read(studyItemProvider(widget.id).future);
      _item = item;
      if (item['is_free'] != true && !_secured) {
        _secured = true;
        await SecureScreen.on();
      }
      final files = Map<String, dynamic>.from((item['files'] as Map?) ?? const {});
      if (files['360'] != true) {
        setState(() => _loading = false);
        return;
      }
      final saver = ref.read(settingsProvider).dataSaver;
      await _open(_quality ?? (!saver && files['720'] == true ? '720' : '360'));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(String quality, {Duration? at}) async {
    setState(() => _loading = true);
    final url = await _repo.fileUrl(widget.id, quality);
    final old = _ctl;
    final ctl = VideoPlayerController.networkUrl(Uri.parse(url));
    await ctl.initialize();
    final pos = Map<String, dynamic>.from(
      firstOr((ref.read(studyProgressProvider).value ?? const []), (p) => p['item_id'] == widget.id)['position'] as Map? ?? const {},
    );
    final resume = at ?? Duration(seconds: (pos['seconds'] as num?)?.toInt() ?? 0);
    if (resume > Duration.zero && resume < ctl.value.duration - const Duration(seconds: 5)) await ctl.seekTo(resume);
    await ctl.setPlaybackSpeed(_speed);
    ctl.addListener(_tick);
    if (!mounted) {
      await ctl.dispose();
      return;
    }
    setState(() {
      _ctl = ctl;
      _quality = quality;
      _loading = false;
    });
    await old?.dispose();
    await ctl.play();
    _saver?.cancel();
    _saver = Timer.periodic(const Duration(seconds: 15), (_) => _save());
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _save() {
    final c = _ctl, item = _item;
    if (c == null || item == null || !c.value.isInitialized) return;
    final d = c.value.duration.inMilliseconds;
    if (d <= 0) return;
    _repo.saveProgress(item, c.value.position.inMilliseconds / d, position: {'seconds': c.value.position.inSeconds});
  }

  @override
  void dispose() {
    _save();
    _saver?.cancel();
    _ctl?.removeListener(_tick);
    _ctl?.dispose();
    if (_secured) SecureScreen.off();
    super.dispose();
  }

  Future<void> _more() async {
    final files = Map<String, dynamic>.from((_item?['files'] as Map?) ?? const {});
    await showSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Video options', style: ctx.ty.h3),
          const Gap(Space.s4),
          Text('Quality', style: ctx.ty.label),
          const Gap(Space.s2),
          Seg<String>(
            value: _quality ?? '360',
            items: [('360', '360p (data saver)'), if (files['720'] == true) ('720', '720p HD')],
            onChanged: (q) {
              Navigator.of(ctx).pop();
              if (q != _quality) _open(q, at: _ctl?.value.position);
            },
          ),
          const Gap(Space.s4),
          Text('Speed', style: ctx.ty.label),
          const Gap(Space.s2),
          Seg<double>(
            value: _speed,
            items: const [(0.75, '0.75×'), (1.0, '1×'), (1.25, '1.25×'), (1.5, '1.5×')],
            onChanged: (s) {
              Navigator.of(ctx).pop();
              setState(() => _speed = s);
              _ctl?.setPlaybackSpeed(s);
            },
          ),
          const Gap(Space.s4),
          ListCard(
            children: [
              ListRow(
                icon: PhosphorIcons.flag(PhosphorIconsStyle.fill),
                tone: Tone.neutral,
                title: 'Report a problem',
                caret: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  toast(context, 'Thanks. Our team will check this video.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final item = _item;
    final err = _error;
    final locked = err is ApiError && err.status == 402;
    final lesson = item?['kind'] == 'lesson';
    return Scaffold(
      appBar: TopBar(
        title: lesson ? 'Topic lesson' : 'Video solution',
        actions: [
          if (item != null) BookmarkButton(kind: 'item', refId: '${item['kind']}:${widget.id}', label: '${item['title']}'),
          if (_ctl != null) IconBtn(PhosphorIcons.dotsThreeVertical(), label: 'More options', onPressed: _more),
        ],
      ),
      body: locked
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'Video solutions are for Premium',
                  text: 'Your plan does not include this video. Go Premium to open it, with every past-question year.',
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
                _Player(ctl: _ctl, loading: _loading, subjectIcon: subjectIconFor(ref, item['subject_id']), hasFile: (item['files'] as Map?)?['360'] == true),
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
                      if (_ctl != null) ...[
                        const Gap(Space.s4),
                        Row(
                          children: [
                            Btn(
                              _quality == '720' ? '720p' : '360p',
                              kind: BtnKind.outline,
                              sm: true,
                              leading: PhosphorIcons.slidersHorizontal(),
                              onPressed: _more,
                            ),
                          ],
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

class _Player extends StatelessWidget {
  const _Player({required this.ctl, required this.loading, required this.subjectIcon, required this.hasFile});
  final VideoPlayerController? ctl;
  final bool loading, hasFile;
  final IconData subjectIcon;

  String _t(Duration d) => clock(d.inSeconds);

  @override
  Widget build(BuildContext context) {
    final c = ctl;
    if (c == null || !c.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          VideoThumb(index: 0, subjectIcon: subjectIcon, radius: 0, big: true),
          if (loading)
            const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          else if (!hasFile)
            Positioned(
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xC706132B), borderRadius: BorderRadius.circular(99)),
                child: Text('The video has not been added yet', style: context.ty.cap.bold.col(Colors.white)),
              ),
            ),
        ],
      );
    }
    final v = c.value;
    final total = v.duration.inMilliseconds;
    final frac = total == 0 ? 0.0 : v.position.inMilliseconds / total;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => v.isPlaying ? c.pause() : c.play(),
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)),
              ),
              if (v.isBuffering || loading) const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              if (!v.isPlaying && !v.isBuffering)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle),
                  child: Semantics(
                    label: 'Play',
                    child: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 26, color: Palette.navy900),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 6,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Palette.gold400,
                        inactiveTrackColor: Colors.white.withValues(alpha: .25),
                        thumbColor: Palette.gold400,
                      ),
                      child: SizedBox(
                        height: 20,
                        child: Slider(
                          value: frac.clamp(0, 1),
                          onChanged: (x) => c.seekTo(Duration(milliseconds: (x * total).round())),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_t(v.position), style: context.ty.cap.col(Colors.white)),
                        Text(_t(v.duration), style: context.ty.cap.col(Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
