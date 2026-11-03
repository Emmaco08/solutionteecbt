import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../data/ai_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/note_markdown.dart';
import '../../widgets/phosphor.g.dart';
import '../premium/paywall.dart';
import '../study/note_screens.dart' show NoteBody;

/// One bubble in the chat.
class _Msg {
  _Msg({required this.mine, this.text = '', this.image, this.hasImage = false, this.id, this.done = true, this.flagged = false});
  final bool mine;
  String text;
  final Uint8List? image;
  final bool hasImage;
  String? id;
  bool done, thinking = false, flagged;
  String? error;
  NoteDoc? _doc;
  String? _docText;

  NoteDoc doc() {
    if (_doc == null || _docText != text) {
      _doc = NoteDoc.parse(text);
      _docText = text;
    }
    return _doc!;
  }
}

const _suggestions = [
  r'Explain how to solve $x^2 - 5x + 6 = 0$',
  'What is the difference between speed and velocity?',
  'Give me 3 tips for JAMB Use of English',
];

/// SolutionTee AI chat (prototype `ai` and `ai-out`). [questionId] opens with "explain this past question".
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key, this.chatId, this.questionId, this.questionLabel});
  final String? chatId, questionId, questionLabel;
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  String? _chatId, _attachedLabel;
  int? _subject;
  bool _hint = false, _loadingChat = false;
  Uint8List? _photo;
  int _photoOrigKb = 0;
  StreamSubscription<AiEvent>? _sub;
  Timer? _paint;
  late final AiRepo _repo;

  bool get _busy => _sub != null;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(aiRepoProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply(widget));
  }

  @override
  void didUpdateWidget(AiScreen old) {
    super.didUpdateWidget(old);
    if (old.chatId != widget.chatId || old.questionId != widget.questionId) _apply(widget);
  }

  /// Opens a saved chat, or starts "explain this past question".
  void _apply(AiScreen w) {
    if (w.chatId != null && w.chatId != _chatId) _openChat(w.chatId!);
    if (w.questionId != null) {
      _newChat();
      _attachedLabel = w.questionLabel ?? 'Past question';
      _send(questionId: w.questionId, explain: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _paint?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openChat(String id) async {
    _stop();
    setState(() {
      _loadingChat = true;
      _msgs.clear();
      _chatId = id;
      _attachedLabel = null;
    });
    try {
      final rows = await _repo.messages(id);
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          _msgs.add(
            _Msg(
              mine: r['role'] == 'user',
              text: '${r['content'] ?? ''}',
              hasImage: r['has_image'] == true,
              id: r['id'] as String?,
              flagged: r['flagged_at'] != null,
            ),
          );
        }
      });
      _toEnd();
    } catch (_) {
      if (mounted) toast(context, 'Could not open that chat. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  void _newChat() {
    _stop();
    setState(() {
      _msgs.clear();
      _chatId = null;
      _attachedLabel = null;
      _photo = null;
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _repo.stop();
    if (_msgs.isNotEmpty && !_msgs.last.mine && !_msgs.last.done) {
      _msgs.last
        ..done = true
        ..thinking = false;
      if (_msgs.last.text.isEmpty) _msgs.removeLast();
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Motion.base, curve: Curves.easeOut);
    });
  }

  /// Repaints the streaming answer at most ~16 times a second (keeps it smooth on 3 GB phones).
  void _schedulePaint() {
    if (_paint?.isActive ?? false) return;
    _paint = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      setState(() {});
      final p = _scroll.hasClients ? _scroll.position : null;
      if (p != null && p.maxScrollExtent - p.pixels < 160) _scroll.jumpTo(p.maxScrollExtent);
    });
  }

  void _send({String? text, String? questionId, bool explain = false}) {
    if (_busy) return;
    final t = (text ?? _input.text).trim();
    final photo = _photo;
    if (t.isEmpty && photo == null && questionId == null) return;
    HapticFeedback.lightImpact();
    final reply = _Msg(mine: false, done: false);
    setState(() {
      _msgs.add(_Msg(mine: true, text: t.isEmpty && questionId != null ? 'Explain this question.' : t, image: photo, hasImage: photo != null));
      _msgs.add(reply);
      _input.clear();
      _photo = null;
    });
    _toEnd();
    _sub = _repo
        .ask(
          chatId: _chatId,
          text: t,
          imageBase64: photo == null ? null : base64Encode(photo),
          subjectId: _subject,
          hint: _hint,
          questionId: questionId,
          explain: explain,
        )
        .listen(
          (e) {
            switch (e) {
              case AiStart(:final chatId):
                _chatId = chatId;
              case AiThinking():
                if (!reply.thinking && reply.text.isEmpty) setState(() => reply.thinking = true);
              case AiDelta(:final text):
                reply
                  ..thinking = false
                  ..text += text;
                _schedulePaint();
              case AiDone(:final messageId):
                setState(() {
                  reply
                    ..id = messageId
                    ..done = true
                    ..thinking = false;
                });
              case AiFailed(:final message, :final code):
                setState(() {
                  reply
                    ..done = true
                    ..thinking = false
                    ..error = message;
                });
                if (code == 'quota') ref.invalidate(aiQuotaProvider);
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _sub = null;
              if (!reply.done) {
                reply.done = true;
                if (reply.text.isEmpty && reply.error == null) reply.error = 'The answer did not arrive. Try again.';
              }
            });
            _toEnd();
          },
        );
  }

  Future<void> _pickPhoto() async {
    final src = await showSheet<ImageSource>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a photo', style: ctx.ty.h3),
          const Gap(Space.s2),
          Text('Snap your question so all of it is clear, well lit and not blurry. One photo uses 1 AI prompt.', style: ctx.ty.sm.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          ListCard(
            children: [
              ListRow(
                icon: PhosphorIcons.camera(PhosphorIconsStyle.fill),
                title: 'Take a photo',
                caption: 'Opens your camera',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListRow(
                icon: PhosphorIcons.images(PhosphorIconsStyle.fill),
                title: 'Choose from gallery',
                caption: 'Screenshots and saved photos',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
          const Gap(Space.s3),
          Text('Photos are shrunk on your phone before upload and are only used to answer your question.', style: ctx.ty.cap.col(ctx.c.textSubtle)),
        ],
      ),
    );
    if (src == null) return;
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 72);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) toast(context, 'That photo is too large. Try a closer, simpler photo.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        return;
      }
      setState(() {
        _photo = bytes;
        _photoOrigKb = (bytes.length / 1024).round();
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not open the camera or gallery.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _report(_Msg m) async {
    final reasons = ['The answer is wrong', 'The working has a mistake', 'It did not answer my question', 'Hard to understand', 'Something else'];
    final pick = await showSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What was wrong?', style: ctx.ty.h3),
          const Gap(Space.s2),
          Text('Our teachers check every report and improve the tutor.', style: ctx.ty.sm.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          ListCard(
            children: [for (final r in reasons) ListRow(title: r, onTap: () => Navigator.of(ctx).pop(r))],
          ),
        ],
      ),
    );
    if (pick == null || m.id == null) return;
    try {
      await _repo.flag(m.id!, pick);
      setState(() => m.flagged = true);
      if (mounted) toast(context, 'Thanks. Our team will check this answer.', icon: PhosphorIcons.flag(PhosphorIconsStyle.fill));
    } catch (_) {
      if (mounted) toast(context, 'Could not send the report. Try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final quota = ref.watch(aiQuotaProvider).value;
    final left = (quota?['left'] as num?)?.toInt();
    final limit = (quota?['limit'] as num?)?.toInt();
    final out = left == 0 && !_busy;
    final profile = ref.watch(profileProvider).value;
    final first = '${profile?['full_name'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final mine = [for (final code in (profile?['jamb_subjects'] as List? ?? const [])) ...subjects.where((s) => s['code'] == code)];
    final chips = mine.isEmpty ? subjects.take(5).toList() : mine;
    final dark = context.isDark;

    return Scaffold(
      appBar: TopBar(
        showBack: false,
        lined: true,
        center: Padding(
          padding: const EdgeInsets.only(left: Space.s3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SolutionTee AI', style: context.ty.h3),
              Text('Your step-by-step tutor', style: context.ty.cap.col(c.textMuted)),
            ],
          ),
        ),
        actions: [
          if (left != null && limit != null) _QuotaChip(left: left, limit: limit),
          IconBtn(PhosphorIcons.clockCounterClockwise(), label: 'Past chats', onPressed: () => context.push('/ai/history')),
          IconBtn(PhosphorIcons.notePencil(), label: 'New chat', onPressed: _newChat),
        ],
      ),
      body: Column(
        children: [
          if (chips.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                child: Row(
                  children: [
                    AppChip('Any subject', on: _subject == null, onTap: () => setState(() => _subject = null)),
                    for (final s in chips) ...[
                      const Gap(Space.s2),
                      AppChip('${s['name']}', on: _subject == s['id'], onTap: () => setState(() => _subject = (s['id'] as num).toInt())),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: out && _msgs.isEmpty
                ? _QuotaOut(limit: limit ?? 0, resetsAt: DateTime.tryParse('${quota?['resets_at']}'))
                : _loadingChat
                ? const Center(child: CircularProgressIndicator())
                : _msgs.isEmpty
                ? _Welcome(
                    first: first,
                    onSuggest: (s) => _send(text: s),
                    onSnap: _pickPhoto,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s3),
                    itemCount: _msgs.length + (_attachedLabel != null ? 1 : 0) + (out ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_attachedLabel != null) {
                        if (i == 0) return _Attached(label: _attachedLabel!);
                        i--;
                      }
                      if (i == _msgs.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: Space.s3),
                          child: InfoBanner(
                            kind: BannerKind.err,
                            icon: PhosphorIcons.hourglassLow(PhosphorIconsStyle.fill),
                            child: GestureDetector(
                              onTap: () => showPaywall(context, reason: 'ai'),
                              child: const Text("That was your last prompt today. Tap to see Premium (100 a day)."),
                            ),
                          ),
                        );
                      }
                      final m = _msgs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Space.s3),
                        child: m.mine
                            ? _MyBubble(m: m)
                            : _AiBubble(
                                m: m,
                                dark: dark,
                                onCopy: () {
                                  Clipboard.setData(ClipboardData(text: m.text));
                                  toast(context, 'Copied', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
                                },
                                onReport: () => _report(m),
                                onRetry: i > 0 && _msgs[i - 1].mine
                                    ? () {
                                        final q = _msgs[i - 1];
                                        setState(() => _msgs.removeRange(i - 1, i + 1));
                                        if (q.image != null) _photo = q.image;
                                        _send(text: q.text);
                                      }
                                    : null,
                              ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 4, Space.s4, 4),
            child: Row(
              children: [
                SizedBox(
                  height: 28,
                  child: FittedBox(
                    child: AppSwitch(value: _hint, onChanged: (v) => setState(() => _hint = v)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _hint = !_hint),
                  child: Text('Hint mode', style: context.ty.cap.bold),
                ),
                const Spacer(),
                Text('AI can make mistakes.', style: context.ty.cap.col(c.textMuted)),
              ],
            ),
          ),
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photo!, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Question photo', style: context.ty.sm.bold),
                        Text('$_photoOrigKb KB · shrunk to save data', style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                  IconBtn(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), label: 'Remove photo', onPressed: () => setState(() => _photo = null)),
                ],
              ),
            ),
          _Composer(
            controller: _input,
            busy: _busy,
            disabled: out,
            hasPhoto: _photo != null,
            onAttach: _pickPhoto,
            onSend: () => _send(),
            onStop: () => setState(_stop),
          ),
        ],
      ),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.left, required this.limit});
  final int left, limit;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final outOf = left <= 0;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: outOf ? c.errorSoft : c.accentSoft, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 14, color: outOf ? c.onErrorSoft : c.onAccentSoft),
          const SizedBox(width: 4),
          Text('$left of $limit', style: context.ty.cap.bold.tnum.col(outOf ? c.onErrorSoft : c.onAccentSoft)),
        ],
      ),
    ).animate(key: ValueKey(left)).scaleXY(begin: 1.12, end: 1, duration: Motion.base, curve: Curves.easeOutBack);
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.first, required this.onSuggest, required this.onSnap});
  final String first;
  final ValueChanged<String> onSuggest;
  final VoidCallback onSnap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget item(int i, Widget child) => rm ? child : child.animate().fadeIn(delay: (60 * i).ms, duration: Motion.base).slideY(begin: .1, end: 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s5, Space.s4, Space.s4),
      children: [
        Center(child: IconTile(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), tone: Tone.gold, size: 76, radius: 24, iconSize: 36)),
        const Gap(Space.s3),
        Text(first.isEmpty ? 'What are we solving today?' : 'Hi $first, what are we solving today?', textAlign: TextAlign.center, style: context.ty.h3),
        const Gap(Space.s2),
        Text(
          'I explain step by step, like a patient teacher. Turn on hint mode if you want clues, not answers.',
          textAlign: TextAlign.center,
          style: context.ty.sm.col(c.textMuted),
        ),
        const Gap(Space.s5),
        item(
          0,
          _Suggestion(
            icon: PhosphorIcons.camera(),
            bold: 'Snap a question.',
            text: ' Take a photo of your textbook or past question and I will solve it.',
            onTap: onSnap,
          ),
        ),
        for (final (i, s) in _suggestions.indexed) item(i + 1, _Suggestion(icon: PhosphorIcons.arrowUpRight(), text: s, onTap: () => onSuggest(s))),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.icon, required this.text, required this.onTap, this.bold});
  final IconData icon;
  final String text;
  final String? bold;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s2),
    child: AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.c.secondary),
          const Gap(Space.s3),
          Expanded(
            child: bold == null
                ? MathText(text, style: context.ty.sm)
                : Text.rich(
                    TextSpan(
                      style: context.ty.sm,
                      children: [
                        TextSpan(
                          text: bold,
                          style: const TextStyle(fontWeight: kBold),
                        ),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _Attached extends StatelessWidget {
  const _Attached({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Space.s3),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: context.c.secondarySoft, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(PhosphorIcons.paperclip(PhosphorIconsStyle.fill), size: 16, color: context.c.onSecondarySoft),
        const SizedBox(width: 6),
        Expanded(child: Text('Attached: $label', style: context.ty.cap.bold.col(context.c.onSecondarySoft))),
      ],
    ),
  );
}

class _MyBubble extends StatelessWidget {
  const _MyBubble({required this.m});
  final _Msg m;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
        child: Container(
          padding: EdgeInsets.all(m.image != null ? 6 : 12),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(m.image!, width: 220, fit: BoxFit.cover),
                )
              else if (m.hasImage)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.image(PhosphorIconsStyle.fill), size: 16, color: c.onPrimary),
                    const SizedBox(width: 6),
                    Text('Photo', style: context.ty.sm.bold.col(c.onPrimary)),
                  ],
                ),
              if (m.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    m.image != null ? 8 : 0,
                    m.image != null || m.hasImage ? 6 : 0,
                    m.image != null ? 8 : 0,
                    m.image != null ? 6 : 0,
                  ),
                  child: MathText(m.text, style: context.ty.body.col(c.onPrimary).copyWith(height: 23 / 15)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.m, required this.dark, required this.onCopy, required this.onReport, this.onRetry});
  final _Msg m;
  final bool dark;
  final VoidCallback onCopy, onReport;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Widget content;
    if (m.error != null && m.text.isEmpty) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.error!, style: context.ty.sm.col(c.error)),
          if (onRetry != null) ...[
            const Gap(Space.s2),
            Btn('Try again', kind: BtnKind.outline, sm: true, leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
          ],
        ],
      );
    } else if (m.text.isEmpty) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TypingDots(),
          if (m.thinking) ...[const SizedBox(width: 8), Text('Thinking…', style: context.ty.cap.col(c.textMuted))],
        ],
      );
    } else {
      content = NoteBody(text: m.text, scale: .94);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: RepaintBoundary(child: content),
            ),
            if (m.done && m.text.isNotEmpty)
              Row(
                children: [
                  IconBtn(PhosphorIcons.copy(), label: 'Copy', size: 18, color: c.textSubtle, onPressed: onCopy),
                  IconBtn(
                    m.flagged ? PhosphorIcons.flag(PhosphorIconsStyle.fill) : PhosphorIcons.thumbsDown(),
                    label: 'This answer is wrong',
                    size: 18,
                    color: m.flagged ? c.error : c.textSubtle,
                    onPressed: m.flagged || m.id == null ? null : onReport,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: context.c.textSubtle, shape: BoxShape.circle),
          ).animate(onPlay: (a) => rm ? null : a.repeat(reverse: true)).fadeIn(begin: .3, delay: (150 * i).ms, duration: 450.ms),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.disabled,
    required this.hasPhoto,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
  });
  final TextEditingController controller;
  final bool busy, disabled, hasPhoto;
  final VoidCallback onAttach, onSend, onStop;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      child: Opacity(
        opacity: disabled ? .55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconBtn(PhosphorIcons.cameraPlus(), label: 'Add a photo', onPressed: disabled || busy ? null : onAttach),
              Expanded(
                // One rounded pill only: the app's text-field theme (fill + focus border) is switched off inside it,
                // and the pill itself turns blue while typing (prototype `.composer .input`).
                child: _FocusPill(
                  child: TextField(
                    controller: controller,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.ty.body,
                    decoration: InputDecoration(
                      filled: false,
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: disabled ? 'Prompts reset at midnight' : (hasPhoto ? 'Add a note (optional)' : 'Ask any question…'),
                      hintStyle: context.ty.body.col(c.textSubtle),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
              const Gap(Space.s2),
              Semantics(
                button: true,
                label: busy ? 'Stop' : 'Send',
                child: Pressable(
                  onTap: disabled ? null : (busy ? onStop : onSend),
                  scale: .9,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: busy ? c.surfaceSunken : c.primary, shape: BoxShape.circle),
                    child: Icon(
                      busy ? PhosphorIcons.stop(PhosphorIconsStyle.fill) : PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                      size: 20,
                      color: busy ? c.text : c.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The composer's rounded box: 1.5 px border, secondary blue while the text field has focus.
class _FocusPill extends StatefulWidget {
  const _FocusPill({required this.child});
  final Widget child;
  @override
  State<_FocusPill> createState() => _FocusPillState();
}

class _FocusPillState extends State<_FocusPill> {
  bool _focus = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (f) => setState(() => _focus = f),
      child: AnimatedContainer(
        duration: Motion.fast,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _focus ? c.secondary : c.border, width: _focus ? 2 : 1.5),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Prototype `ai-out`: today's prompts are used up; countdown to midnight Lagos time.
class _QuotaOut extends StatefulWidget {
  const _QuotaOut({required this.limit, required this.resetsAt});
  final int limit;
  final DateTime? resetsAt;
  @override
  State<_QuotaOut> createState() => _QuotaOutState();
}

class _QuotaOutState extends State<_QuotaOut> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final left = widget.resetsAt == null ? Duration.zero : widget.resetsAt!.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    final cd = '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.all(Space.s5),
      children: [
        StateBlock(
          icon: PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill),
          tone: Tone.gold,
          title: "You have used today's ${widget.limit} prompts",
          text: 'Your prompts reset at midnight, Lagos time. Come back in $cd.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(12)),
                    child: Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 22, color: Palette.navy900),
                  ),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Premium gets 100 prompts a day', style: context.ty.body.bold),
                        Text('Plus every year, every exam and all videos.', style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(Space.s3),
              Btn(
                'See Premium plans',
                kind: BtnKind.accent,
                block: true,
                onPressed: () => showPaywall(context, reason: 'ai'),
              ),
            ],
          ),
        ),
        const Gap(Space.s3),
        Center(
          child: Btn('Study past questions instead', kind: BtnKind.ghost, onPressed: () => context.go('/study')),
        ),
      ],
    );
  }
}

/// Past chats (newest first). Tap to continue, the bin to delete.
class AiHistoryScreen extends ConsumerWidget {
  const AiHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiChatsProvider);
    final chats = async.value ?? const [];
    return Scaffold(
      appBar: const TopBar(title: 'Past chats'),
      body: async.isLoading && chats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : async.hasError && chats.isEmpty
          ? Center(
              child: StateBlock(
                icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill),
                tone: Tone.gold,
                title: 'You are offline',
                text: 'Connect to the internet to see your past chats.',
                action: Btn('Try again', onPressed: () => ref.invalidate(aiChatsProvider)),
              ),
            )
          : chats.isEmpty
          ? Center(
              child: StateBlock(
                icon: PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill),
                tone: Tone.blue,
                title: 'No chats yet',
                text: 'Ask SolutionTee AI a question and your chats will be kept here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                ListCard(
                  children: [
                    for (final ch in chats)
                      ListRow(
                        icon: PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
                        tone: Tone.blue,
                        title: '${ch['title']}',
                        caption: _ago(ch['updated_at'] as String?),
                        onTap: () => context.go('/ai?chat=${ch['id']}'),
                        trailing: IconBtn(
                          PhosphorIcons.trash(),
                          label: 'Delete chat',
                          onPressed: () async {
                            await ref.read(aiRepoProvider).deleteChat(ch['id'] as String);
                            if (context.mounted) toast(context, 'Chat deleted', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _ago(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// "Ask AI" from a past question: opens the AI tab with the question attached.
void askAiAbout(BuildContext context, {required String questionId, required String label}) =>
    context.go('/ai?q=$questionId&label=${Uri.encodeComponent(label)}');
