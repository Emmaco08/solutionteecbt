import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
import 'ai_cards.dart';
import 'ai_actions.dart';

/// One bubble in the chat.
class _Msg {
  _Msg({required this.mine, this.text = '', this.image, this.hasImage = false, this.id, this.done = true, this.flagged = false});
  final bool mine;
  String text;
  final Uint8List? image;
  final bool hasImage;
  String? id;
  bool done, thinking = false, flagged;
  String? error, errorCode;

  /// U3b: the answer is being finished by the server while the phone was away; [reaction] is one of the six emoji;
  /// [followups] are the "What next?" chips; [hintLevel] (1-3) marks a hint reply.
  bool background = false, finishing = false;
  String? reaction;
  List<String> followups = const [];
  List<String> steps = const [];
  Map<String, dynamic>? pendingCard;
  int? hintLevel;

  /// A tool card: [toolRunning] shows the working card, then [card] replaces it.
  String? toolName, toolLabel;
  bool toolRunning = false, free = false;
  Map<String, dynamic>? card;
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
  AiChip(r'Explain how to solve $x^2 - 5x + 6 = 0$'),
  AiChip('What is the difference between speed and velocity?'),
  AiChip('Give me 3 tips for JAMB Use of English'),
];

/// SolutionTee AI chat (prototype `ai` and `ai-out`). [questionId] opens with "explain this past question".
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key, this.chatId, this.questionId, this.questionLabel, this.tool, this.toolArgs});
  final String? chatId, questionId, questionLabel;

  /// Deep link `/ai?tool=quiz&args={json}&label=Text`: sends that chip once when the screen opens (the label is its text).
  final String? tool;
  final Map<String, dynamic>? toolArgs;

  static Map<String, dynamic>? parseArgs(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _focus = FocusNode();
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
  final _speech = SpeechToText();
  // The mic shows until the phone says it has no speech recogniser; the microphone is asked for on the first tap.
  bool _voiceOk = true, _voiceReady = false, _listening = false;
  String _voiceBase = '';

  // Hint ladder: the question being hinted (to resend with a higher level) and the level "Check my working" continues at.
  String? _hintQuestion, _replyQuote, _sentLink;
  Uint8List? _hintPhoto;
  int? _workingLevel;

  // Background answers: the reply being finished by the server, polled every 3 s for up to 3 minutes.
  _Msg? _bg, _curReply;
  bool _curStarted = false, _bgPolling = false;
  Set<String> _bgBaseline = const {};
  Timer? _bgTimer, _stepTimer;
  final _bgWatch = Stopwatch();
  static const _bgLimit = Duration(minutes: 3);

  bool get _busy => _sub != null || _bg != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = ref.read(aiRepoProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply(widget));
  }

  /// First tap on the mic: Android asks for the microphone here, not when the screen opens.
  Future<bool> _initVoice() async {
    if (_voiceReady) return true;
    try {
      _voiceReady = await _speech.initialize(onStatus: _voiceStatus, onError: (_) => _voiceStop());
    } catch (_) {
      _voiceReady = false;
    }
    if (!_voiceReady && mounted) {
      setState(() => _voiceOk = false);
      toast(context, 'Voice typing is not available. Allow the microphone in Settings, or type your question.', icon: PhosphorIcons.microphone());
    }
    return _voiceReady;
  }

  void _voiceStatus(String s) {
    if ((s == 'done' || s == 'notListening') && _listening && mounted) setState(() => _listening = false);
  }

  void _voiceStop() {
    if (_listening) {
      _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      _voiceStop();
      return;
    }
    HapticFeedback.selectionClick();
    if (!await _initVoice() || !mounted) return;
    _voiceBase = _input.text.trim();
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (r) {
          final said = r.recognizedWords;
          final t = _voiceBase.isEmpty ? said : '$_voiceBase $said';
          _input.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 4),
          listenFor: const Duration(seconds: 60),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        toast(context, 'Could not use the microphone.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
      }
    }
  }

  @override
  void didUpdateWidget(AiScreen old) {
    super.didUpdateWidget(old);
    if (old.chatId != widget.chatId ||
        old.questionId != widget.questionId ||
        old.tool != widget.tool ||
        old.toolArgs.toString() != widget.toolArgs.toString()) {
      _apply(widget);
    }
  }

  /// Opens a saved chat, or starts "explain this past question".
  void _apply(AiScreen w) {
    if (w.chatId != null && w.chatId != _chatId) _openChat(w.chatId!);
    if (w.tool != null && w.questionId == null) {
      final key = '${w.tool}|${w.toolArgs}|${w.questionLabel}';
      if (key != _sentLink) {
        _sentLink = key;
        _newChat();
        _send(text: (w.questionLabel ?? '').trim().isEmpty ? w.tool : w.questionLabel, tool: w.tool, args: w.toolArgs);
      }
    }
    if (w.questionId != null) {
      _newChat();
      _attachedLabel = w.questionLabel ?? 'Past question';
      _send(questionId: w.questionId, explain: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // The stream will die with the phone asleep; the server still saves the answer. Show that, and poll.
      final r = _curReply;
      if (_sub != null && r != null && !r.done && _curStarted && _chatId != null && _bg == null) {
        if (mounted) setState(() => _startBg(r));
      }
    } else if (state == AppLifecycleState.resumed && _bg != null) {
      _pollBg(tick: false);
    }
  }

  void _startBg(_Msg reply) {
    reply
      ..background = true
      ..thinking = false
      ..toolRunning = false
      ..finishing = false
      ..toolName = null
      ..error = null;
    _bgBaseline = {
      for (final m in _msgs)
        if (m.id != null) m.id!,
    };
    _bg = reply;
    _bgWatch
      ..reset()
      ..start();
    _bgTimer?.cancel();
    _bgTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollBg());
  }

  void _endBg() {
    _bgTimer?.cancel();
    _bgTimer = null;
    _bgWatch.stop();
    _bg?.background = false;
    _bg = null;
  }

  Future<void> _pollBg({bool tick = true}) async {
    final reply = _bg, chat = _chatId;
    if (reply == null || chat == null || _bgPolling) return;
    _bgPolling = true;
    Map<String, dynamic>? found;
    try {
      final rows = await _repo.messages(chat);
      for (final r in rows.reversed) {
        if (r['role'] == 'assistant' && !_bgBaseline.contains(r['id'])) {
          found = r;
          break;
        }
      }
    } catch (_) {
      // Offline for a moment: try again on the next tick.
    } finally {
      _bgPolling = false;
    }
    if (!mounted || _bg != reply) return;
    if (found != null) {
      setState(() {
        _fillFromRow(reply, found!);
        _endBg();
        _sub?.cancel();
        _sub = null;
      });
      _repo.stop();
      ref.invalidate(aiSuggestionsProvider);
      ref.invalidate(aiQuotaProvider);
      _toEnd();
    } else if (_bgWatch.elapsed >= _bgLimit) {
      setState(() {
        _endBg();
        _sub?.cancel();
        _sub = null;
        reply
          ..done = true
          ..error = 'The answer did not arrive. Try again.'
          ..errorCode = 'net';
      });
      _repo.stop();
    }
  }

  /// Fills a bubble from a saved `ai_messages` row (text, card, follow-ups, reaction).
  void _fillFromRow(_Msg m, Map<String, dynamic> r) {
    final card = r['card'] is Map ? Map<String, dynamic>.from(r['card'] as Map) : null;
    m
      ..text = '${r['content'] ?? ''}'
      ..id = r['id'] as String?
      ..card = card
      ..toolName = null
      ..toolRunning = false
      ..thinking = false
      ..error = null
      ..done = true
      ..background = false
      ..reaction = r['reaction'] as String?
      ..followups = _followupsOf(card);
  }

  static List<String> _followupsOf(Map<String, dynamic>? card) => [
    for (final f in (card?['followups'] as List? ?? const []))
      if ('$f'.trim().isNotEmpty) '$f',
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    _stepTimer?.cancel();
    _focus.dispose();
    _sub?.cancel();
    _paint?.cancel();
    if (_listening) _speech.cancel();
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
              )
              ..card = r['card'] is Map ? Map<String, dynamic>.from(r['card'] as Map) : null
              ..reaction = r['reaction'] as String?,
          );
          _msgs.last.followups = _followupsOf(_msgs.last.card);
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
      _replyQuote = null;
      _hintQuestion = null;
      _workingLevel = null;
      _chatId = null;
      _attachedLabel = null;
      _photo = null;
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _repo.stop();
    _stepTimer?.cancel();
    _endBg();
    if (_msgs.isNotEmpty && !_msgs.last.mine && !_msgs.last.done) {
      _msgs.last
        ..done = true
        ..finishing = false
        ..toolRunning = false
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

  /// A suggestion chip: sends its [AiChip.text] (or label) and runs its tool, if it has one. A chip with a chat opens it.
  void _sendChip(AiChip c) {
    if (c.chatId != null) {
      _openChat(c.chatId!);
      return;
    }
    _send(text: c.tool != null ? c.label : (c.text ?? c.label), tool: c.tool, args: c.tool == null ? null : c.args);
  }

  /// The tool finished: tick the last steps, then swap to the card (at once with reduce motion or without steps).
  void _toolDone(_Msg reply, Map<String, dynamic>? card) {
    if (reply.steps.isNotEmpty && !context.reduceMotion && reply.toolRunning) {
      setState(() {
        reply
          ..finishing = true
          ..pendingCard = card;
      });
      _stepTimer?.cancel();
      _stepTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() => _applyCard(reply));
        _toEnd();
      });
    } else {
      setState(() {
        reply.pendingCard = card;
        _applyCard(reply);
      });
      _toEnd();
    }
  }

  void _applyCard(_Msg reply) {
    reply
      ..finishing = false
      ..toolRunning = false
      ..card = reply.pendingCard
      ..pendingCard = null;
  }

  void _send({
    String? text,
    String? shown,
    String? questionId,
    bool explain = false,
    String? tool,
    Map<String, dynamic>? args,
    int? hintLevel,
    Uint8List? photo,
  }) {
    if (_busy) return;
    _voiceStop();
    final fromComposer = text == null;
    var t = (text ?? _input.text).trim();
    final pic = photo ?? _photo;
    if (t.isEmpty && pic == null && questionId == null) return;
    // A reply carries its quote: "> quote\n\nmy text".
    if (fromComposer && _replyQuote != null && t.isNotEmpty) t = '> $_replyQuote\n\n$t';
    HapticFeedback.lightImpact();
    // Hint ladder: a new question starts at level 1; Next hint and Show the answer pass their own level.
    final useHint = _hint || hintLevel != null;
    final level = useHint ? (hintLevel ?? (fromComposer ? _workingLevel : null) ?? 1) : null;
    if (useHint && hintLevel == null && !(fromComposer && _workingLevel != null)) {
      _hintQuestion = t;
      _hintPhoto = pic;
    }
    _workingLevel = null;
    final reply = _Msg(mine: false, done: false)..hintLevel = (useHint && tool == null) ? level : null;
    var started = false;
    setState(() {
      _msgs.add(_Msg(mine: true, text: shown ?? (t.isEmpty && questionId != null ? 'Explain this question.' : t), image: pic, hasImage: pic != null));
      _msgs.add(reply);
      if (fromComposer) {
        _input.clear();
        _replyQuote = null;
      }
      _photo = null;
      _curReply = reply;
      _curStarted = false;
    });
    _toEnd();
    _sub = _repo
        .ask(
          chatId: _chatId,
          text: t,
          imageBase64: pic == null ? null : base64Encode(pic),
          subjectId: _subject,
          hint: useHint,
          hintLevel: level,
          questionId: questionId,
          explain: explain,
          tool: tool,
          args: args,
        )
        .listen(
          (e) {
            switch (e) {
              case AiStart(:final chatId):
                _chatId = chatId;
                started = true;
                _curStarted = true;
              case AiThinking():
                if (!reply.thinking && reply.text.isEmpty) setState(() => reply.thinking = true);
              case AiDelta(:final text):
                reply
                  ..thinking = false
                  ..text += text;
                _schedulePaint();
              case AiTool(:final name, :final running, :final label, :final card, :final steps):
                if (running) {
                  setState(() {
                    reply
                      ..thinking = false
                      ..toolName = name
                      ..toolRunning = true
                      ..finishing = false
                      ..toolLabel = label
                      ..steps = steps;
                  });
                } else {
                  reply
                    ..toolName = name
                    ..thinking = false;
                  _toolDone(reply, card);
                }
              case AiFollowups(:final items):
                setState(() => reply.followups = items.where((x) => x.trim().isNotEmpty).take(3).toList());
                _toEnd();
              case AiDone(:final messageId, :final free):
                setState(() {
                  if (_bg == reply) _endBg();
                  reply
                    ..id = messageId
                    ..done = true
                    ..background = false
                    ..thinking = false
                    ..free = free;
                  if (!reply.finishing) reply.toolRunning = false;
                });
                ref.invalidate(aiSuggestionsProvider);
              case AiFailed(:final message, :final code):
                if (code == 'net' && started && _chatId != null && !reply.done) {
                  // The request reached the server: it finishes and saves the answer even if we lost the connection.
                  if (_bg != reply) setState(() => _startBg(reply));
                } else {
                  setState(() {
                    reply
                      ..done = true
                      ..thinking = false
                      ..toolRunning = false
                      ..finishing = false
                      ..error = message
                      ..errorCode = code;
                  });
                  if (code == 'quota') ref.invalidate(aiQuotaProvider);
                }
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _sub = null;
              if (!reply.done && !reply.background) {
                if (started && _chatId != null) {
                  // The stream ended without "done": the answer may still be saved. Wait for it.
                  _startBg(reply);
                } else {
                  reply.done = true;
                  reply.toolRunning = false;
                  if (reply.text.isEmpty && reply.card == null && reply.error == null) reply.error = 'The answer did not arrive. Try again.';
                }
              }
            });
            _toEnd();
          },
        );
  }

  // ---------------------------------------------------------------- hint ladder, reply, reactions
  void _hintNext(_Msg m) {
    final q = _hintQuestion;
    if (q == null || m.hintLevel == null) return;
    _send(text: q, shown: 'Next hint', hintLevel: math.min(3, m.hintLevel! + 1), photo: _hintPhoto);
  }

  void _hintAnswer() {
    final q = _hintQuestion;
    if (q == null) return;
    _send(text: q, shown: 'Show the answer', hintLevel: 3, photo: _hintPhoto);
  }

  void _checkWorking(_Msg m) {
    _workingLevel = m.hintLevel ?? 1;
    _input.value = const TextEditingValue(text: 'My working: ', selection: TextSelection.collapsed(offset: 12));
    _focus.requestFocus();
    setState(() {});
  }

  void _askAgain(int i) {
    if (_busy || i <= 0 || !_msgs[i - 1].mine) return;
    final q = _msgs[i - 1];
    _send(text: q.text, shown: q.text, photo: q.image);
  }

  Future<void> _react(_Msg m, String? r) async {
    if (m.id == null) {
      toast(context, 'Wait a moment, then try again.', icon: PhosphorIcons.hourglassLow(PhosphorIconsStyle.fill));
      return;
    }
    final prev = m.reaction;
    final next = r == prev ? null : r;
    HapticFeedback.selectionClick();
    setState(() => m.reaction = next);
    try {
      await _repo.react(m.id!, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => m.reaction = prev);
      toast(context, 'Could not save your reaction. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _actions(_Msg m, int i, Offset at) async {
    if (!m.done || m.text.isEmpty) return;
    HapticFeedback.mediumImpact();
    final pick = await showAiActions(
      context,
      at: at,
      current: m.reaction,
      canReport: !m.flagged && m.id != null,
      canAskAgain: !_busy && i > 0 && _msgs[i - 1].mine,
    );
    if (pick == null || !mounted) return;
    if (pick.startsWith('react:')) {
      await _react(m, pick.substring(6));
    } else {
      switch (pick) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: m.text));
          toast(context, 'Copied', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
        case 'reply':
          setState(() => _replyQuote = aiQuoteOf(m.text));
          _focus.requestFocus();
        case 'again':
          _askAgain(i);
        case 'report':
          await _report(m);
      }
    }
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
    final serverChips = ref.watch(aiSuggestionsProvider).value ?? const <AiChip>[];
    final lastAi = _msgs.isNotEmpty && !_msgs.last.mine ? _msgs.last : null;
    final showChips =
        !_busy &&
        !out &&
        lastAi != null &&
        lastAi.done &&
        serverChips.isNotEmpty &&
        lastAi.followups.isEmpty &&
        lastAi.hintLevel == null &&
        lastAi.error == null;

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
                ? _Welcome(first: first, chips: serverChips.isEmpty ? _suggestions : serverChips, onSuggest: _sendChip, onSnap: _pickPhoto)
                : SelectionArea(
                    child: ListView.builder(
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
                        final isLast = i == _msgs.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.s3),
                          child: m.mine
                              ? _MyBubble(m: m)
                              : _AiBubble(
                                  m: m,
                                  dark: dark,
                                  isLast: isLast && !_busy,
                                  onCopy: () {
                                    Clipboard.setData(ClipboardData(text: m.text));
                                    toast(context, 'Copied', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
                                  },
                                  onReport: () => _report(m),
                                  send: _send,
                                  check: _repo.quizCheck,
                                  onOpenChat: _openChat,
                                  onLongPress: (at) => _actions(m, i, at),
                                  onReact: (r) => _react(m, r),
                                  onFollowup: (t) => _send(text: t),
                                  onHintNext: () => _hintNext(m),
                                  onHintAnswer: _hintAnswer,
                                  onHintCheck: () => _checkWorking(m),
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
          ),
          if (showChips)
            Padding(
              padding: const EdgeInsets.only(top: Space.s1, bottom: Space.s1),
              child: AiChipRow(key: ValueKey(serverChips.map((e) => e.label).join('|')), chips: serverChips.take(5).toList(), onTap: _sendChip),
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
          if (_replyQuote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s2, Space.s1),
              child: _QuoteBar(text: _replyQuote!, onCancel: () => setState(() => _replyQuote = null)),
            ),
          _Composer(
            controller: _input,
            focus: _focus,
            busy: _busy,
            disabled: out,
            hasPhoto: _photo != null,
            voice: _voiceOk,
            listening: _listening,
            onMic: _toggleVoice,
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

/// The empty chat: the AI icon breathes and glows with a few floating sparkles, the greeting types in, and the
/// suggestion cards rise in one after another. Under reduce motion everything is still.
class _Welcome extends StatefulWidget {
  const _Welcome({required this.first, required this.chips, required this.onSuggest, required this.onSnap});
  final String first;
  final List<AiChip> chips;
  final ValueChanged<AiChip> onSuggest;
  final VoidCallback onSnap;
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  bool? _moving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final move = !context.reduceMotion;
    if (move == _moving) return;
    _moving = move;
    if (move) {
      _ctl.repeat();
    } else {
      _ctl.stop();
      _ctl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final first = widget.first;
    Widget item(int i, Widget child) =>
        rm ? child : child.animate().fadeIn(delay: (400 + 70 * i).ms, duration: Motion.base).slideY(begin: .12, end: 0, curve: Motion.out);
    final greeting = first.isEmpty ? 'What are we solving today?' : 'Hi $first, what are we solving today?';
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s5, Space.s4, Space.s4),
      children: [
        Center(
          child: SizedBox(
            width: 170,
            height: 120,
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, _) {
                final t = _ctl.value;
                final breathe = rm ? 0.0 : math.sin(t * 2 * math.pi);
                Widget sparkle(double dx, double dy, double size, double phase) {
                  final w = rm ? .75 : (.5 + .5 * math.sin((t + phase) * 2 * math.pi));
                  return Positioned(
                    left: 85 + dx - size / 2,
                    top: 60 + dy - size / 2 - (rm ? 0 : 6 * math.sin((t + phase) * 2 * math.pi)),
                    child: Opacity(
                      opacity: .35 + .65 * w,
                      child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: size, color: c.accent),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    sparkle(-58, -30, 14, 0),
                    sparkle(60, -38, 10, .3),
                    sparkle(-48, 34, 9, .6),
                    sparkle(64, 28, 13, .85),
                    Center(
                      child: Transform.scale(
                        scale: 1 + .045 * breathe,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: c.accent.withValues(alpha: .22 + .16 * (breathe + 1) / 2),
                                blurRadius: 18 + 10 * (breathe + 1) / 2,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: IconTile(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), tone: Tone.gold, size: 76, radius: 24, iconSize: 36),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const Gap(Space.s2),
        _TypedText(greeting, textAlign: TextAlign.center, style: context.ty.h3, still: rm),
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
            onTap: widget.onSnap,
          ),
        ),
        for (final (i, s) in widget.chips.indexed)
          item(
            i + 1,
            _Suggestion(
              icon: s.chatId != null && s.icon == null ? PhosphorIcons.chatsCircle() : aiIconByName(s.icon),
              text: s.label,
              onTap: () => widget.onSuggest(s),
            ),
          ),
      ],
    );
  }
}

/// Text that types itself in (about 30 ms a letter). It keeps its final size from the start so nothing jumps.
class _TypedText extends StatefulWidget {
  const _TypedText(this.text, {required this.style, required this.still, this.textAlign});
  final String text;
  final TextStyle style;
  final bool still;
  final TextAlign? textAlign;
  @override
  State<_TypedText> createState() => _TypedTextState();
}

class _TypedTextState extends State<_TypedText> {
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_TypedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      // Same start ("Hi ..." replaces "What are...") keeps what was typed; otherwise start over.
      _n = 0;
      _start();
    }
  }

  void _start() {
    _t?.cancel();
    if (widget.still) {
      _n = widget.text.length;
      return;
    }
    _t = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) return;
      if (_n >= widget.text.length) {
        t.cancel();
        return;
      }
      setState(() => _n++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.still ? widget.text.length : _n.clamp(0, widget.text.length);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: Text(widget.text, textAlign: widget.textAlign, style: widget.style),
          ),
          Positioned.fill(
            child: Text(widget.text.substring(0, shown), textAlign: widget.textAlign, style: widget.style),
          ),
        ],
      ),
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
    final (quote, body) = aiSplitQuote(m.text);
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
              if (quote != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: c.onPrimary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: c.accent, width: 3)),
                  ),
                  child: Text(quote, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.ty.cap.col(c.onPrimary.withValues(alpha: .85))),
                ),
              if (body.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    m.image != null ? 8 : 0,
                    m.image != null || m.hasImage ? 6 : 0,
                    m.image != null ? 8 : 0,
                    m.image != null ? 6 : 0,
                  ),
                  child: MathText(body, style: context.ty.body.col(c.onPrimary).copyWith(height: 23 / 15)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteBar extends StatelessWidget {
  const _QuoteBar({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: c.secondarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.quotes(PhosphorIconsStyle.fill), size: 16, color: c.onSecondarySoft),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.ty.cap.col(c.onSecondarySoft)),
            ),
          ),
          IconBtn(PhosphorIcons.x(), label: 'Cancel reply', size: 18, color: c.onSecondarySoft, onPressed: onCancel),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.m,
    required this.dark,
    required this.isLast,
    required this.onCopy,
    required this.onReport,
    required this.send,
    required this.check,
    required this.onOpenChat,
    required this.onLongPress,
    required this.onReact,
    required this.onFollowup,
    required this.onHintNext,
    required this.onHintAnswer,
    required this.onHintCheck,
    this.onRetry,
  });
  final _Msg m;
  final AiSendFn send;
  final QuizCheckFn check;
  final bool dark, isLast;
  final VoidCallback onCopy, onReport, onHintNext, onHintAnswer, onHintCheck;
  final VoidCallback? onRetry;
  final ValueChanged<String> onOpenChat, onFollowup;
  final ValueChanged<Offset> onLongPress;
  final ValueChanged<String?> onReact;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final String kind;
    final Widget content;
    if (m.error != null && m.text.isEmpty) {
      kind = 'error';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.error!, style: context.ty.sm.col(c.error)),
          if (m.errorCode == 'locked') ...[
            const Gap(Space.s2),
            Btn(
              'Upgrade',
              kind: BtnKind.accent,
              sm: true,
              leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
              onPressed: () => showPaywall(context, reason: 'years'),
            ),
          ] else if (onRetry != null) ...[
            const Gap(Space.s2),
            Btn('Try again', kind: BtnKind.outline, sm: true, leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
          ],
        ],
      );
    } else if (m.text.isEmpty) {
      kind = 'typing';
      content = m.background
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AiTyping(label: 'Finishing in the background…'),
                const Gap(Space.s2),
                Text('You can leave the app. We will tell you when it is ready.', style: context.ty.cap.col(c.textSubtle)),
              ],
            )
          : AiTyping(label: m.thinking ? 'Thinking…' : null);
    } else {
      kind = 'text';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NoteBody(text: m.text, scale: .94),
          if (m.background) ...[const Gap(Space.s2), const AiTyping(label: 'Finishing in the background…')],
        ],
      );
    }
    final hasCard = m.card != null && m.card!['type'] != null;
    final hasTool = m.toolRunning || m.toolName != null || hasCard;
    // While a tool runs, its working card is the only thing shown; the bubble comes back with text, an error or thinking.
    final showBubble = !(hasTool && m.text.isEmpty && m.error == null && !m.thinking && !m.background);
    final showHint = isLast && m.done && m.hintLevel != null && m.text.isNotEmpty && m.error == null && !m.background;
    final showFollow = isLast && m.done && m.followups.isNotEmpty && !showHint;
    final shape = const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(18),
      bottomLeft: Radius.circular(6),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTool)
              Padding(
                padding: EdgeInsets.only(bottom: m.text.isEmpty && !m.thinking ? 0 : Space.s2),
                child: AiToolSlot(
                  name: m.toolName ?? '${m.card?['type'] ?? ''}',
                  label: m.toolLabel,
                  running: m.toolRunning,
                  finishing: m.finishing,
                  steps: m.steps,
                  card: m.card,
                  send: send,
                  check: check,
                  onOpenChat: onOpenChat,
                ),
              ),
            if (showBubble)
              Padding(
                padding: EdgeInsets.only(bottom: m.reaction != null ? 12 : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onLongPressStart: m.done && m.text.isNotEmpty ? (d) => onLongPress(d.globalPosition) : null,
                      child: Container(
                        width: m.text.isEmpty ? null : double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.border),
                          borderRadius: shape,
                        ),
                        child: RepaintBoundary(
                          child: AnimatedSwitcher(
                            duration: rm ? Duration.zero : Motion.slow,
                            switchInCurve: Motion.out,
                            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
                            child: KeyedSubtree(key: ValueKey(kind), child: content),
                          ),
                        ),
                      ),
                    ),
                    if (m.reaction != null)
                      Positioned(
                        left: 10,
                        bottom: -14,
                        child: Semantics(
                          button: true,
                          label: 'Your reaction ${m.reaction}. Tap to remove',
                          child: GestureDetector(
                            onTap: () => onReact(null),
                            child:
                                Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: c.surface,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(color: c.borderStrong),
                                        boxShadow: context.shadow(1),
                                      ),
                                      child: Text(m.reaction!, style: const TextStyle(fontSize: 14)),
                                    )
                                    .animate(key: ValueKey(m.reaction))
                                    .scaleXY(begin: rm ? 1 : .3, end: 1, duration: rm ? Duration.zero : Motion.base, curve: Curves.easeOutBack),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (m.done && m.hintLevel != null && m.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.s1, left: Space.s1),
                child: HintDots(level: m.hintLevel!),
              ),
            if (m.done && m.free && m.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.s1, left: Space.s1),
                child: Text('Free · no prompt used', style: context.ty.cap.col(c.textSubtle)),
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
            if (showHint) AiHintChips(level: m.hintLevel!, onNext: onHintNext, onAnswer: onHintAnswer, onCheck: onHintCheck),
            if (showFollow) AiFollowupChips(items: m.followups, onTap: onFollowup),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.disabled,
    required this.hasPhoto,
    required this.voice,
    required this.listening,
    required this.onMic,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy, disabled, hasPhoto, voice, listening;
  final VoidCallback onAttach, onSend, onStop, onMic;
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
                    focusNode: focus,
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
              if (voice) _MicButton(listening: listening, onTap: disabled || busy ? null : onMic),
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

/// Microphone button; while listening it shows a pulsing red ring (a still ring with reduce motion).
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget ring = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.errorSoft,
        border: Border.all(color: c.error, width: 2),
      ),
    );
    if (!rm) ring = ring.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: .85, end: 1.15, duration: 700.ms, curve: Curves.easeOut);
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Speak your question',
      child: Pressable(
        onTap: onTap,
        scale: .9,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (listening) ring,
              Icon(listening ? PhosphorIcons.stop(PhosphorIconsStyle.fill) : PhosphorIcons.microphone(), size: 22, color: listening ? c.error : c.text),
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
