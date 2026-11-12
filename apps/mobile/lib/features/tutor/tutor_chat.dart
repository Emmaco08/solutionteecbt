import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../study/study_widgets.dart' show studyPath;
import 'tutor_live.dart';

// The student's chat with their tutor, v3 (D-152, D-153): live messages that heal themselves (tutor_live.dart), reactions,
// swipe or tap to reply, a long-press menu (react, reply, copy, star, delete for everyone, report), an emoji panel,
// hold-to-record voice notes (slide to cancel, slide up to lock, pause), voice playback at 1x / 1.5x / 2x, photos,
// call cards with the real Google Meet, WhatsApp and Zoom logos, study links, read ticks, "online" and "typing…".

/// One chat message, as tutor_overview / tutor_message_send / the table row (Realtime) send it.
class ChatMsg {
  ChatMsg({
    required this.id,
    required this.role,
    required this.kind,
    required this.body,
    this.attachment,
    required this.at,
    this.readAt,
    this.meta = const {},
    this.ref,
    this.pending = false,
    this.failed = false,
    this.localPath,
    this.replyTo,
    this.reply,
    this.reactions = const {},
    this.deleted = false,
    this.starred = false,
  });
  final int id;
  String role, kind, body;
  String? attachment;
  final String? localPath;
  final DateTime at;
  DateTime? readAt;
  Map<String, dynamic> meta;
  Map<String, dynamic>? ref;
  bool pending, failed, deleted, starred;
  int? replyTo;

  /// A short copy of the message this one answers ({id, role, kind, body, deleted}).
  Map<String, dynamic>? reply;

  /// One reaction per side: {student: 👍, tutor: ❤️}.
  Map<String, String> reactions;

  bool get mine => role == 'student';

  factory ChatMsg.from(Map<String, dynamic> j) => ChatMsg(
    id: (j['id'] as num).toInt(),
    role: '${j['role'] ?? j['sender_role'] ?? 'student'}',
    kind: j['deleted_at'] != null ? 'text' : '${j['kind'] ?? 'text'}',
    body: j['deleted_at'] != null ? '' : '${j['body'] ?? ''}',
    attachment: j['deleted_at'] != null ? null : (j['attachment'] ?? j['attachment_path']) as String?,
    at: DateTime.tryParse('${j['at'] ?? j['created_at']}')?.toLocal() ?? DateTime.now(),
    readAt: DateTime.tryParse('${j['read_at'] ?? ''}')?.toLocal(),
    meta: j['meta'] is Map ? Map<String, dynamic>.from(j['meta'] as Map) : const {},
    ref: j['ref'] is Map ? Map<String, dynamic>.from(j['ref'] as Map) : null,
    replyTo: (j['reply_to'] as num?)?.toInt(),
    reply: j['reply'] is Map ? Map<String, dynamic>.from(j['reply'] as Map) : null,
    reactions: {
      if (j['reactions'] is Map)
        for (final e in (j['reactions'] as Map).entries)
          if ('${e.value}'.isNotEmpty) '${e.key}': '${e.value}',
    },
    deleted: j['deleted'] == true || j['deleted_at'] != null,
    starred: j['starred'] == true,
  );

  /// A newer copy of this message from the server. A raw table row (Realtime) has no reply copy or star: keep ours.
  void update(ChatMsg n) {
    kind = n.kind;
    body = n.body;
    attachment = n.attachment;
    meta = n.meta;
    ref = n.ref;
    readAt = n.readAt ?? readAt;
    reactions = n.reactions;
    deleted = n.deleted;
    replyTo = n.replyTo;
    reply = n.reply ?? reply;
    if (n.starred) starred = true;
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The six quick reactions (like WhatsApp), and the emoji panel.
const quickReactions = ['👍', '❤️', '😂', '😮', '🙏', '🔥'];
const emojiGroups = <(String, List<String>)>[
  (
    'Smileys',
    [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '🙂',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😋',
      '😎',
      '🤓',
      '🧐',
      '🤔',
      '🤗',
      '🤭',
      '🤫',
      '😐',
      '😑',
      '😶',
      '🙄',
      '😏',
      '😮',
      '😯',
      '😲',
      '😴',
      '😌',
      '😛',
      '😜',
      '🥲',
      '😢',
      '😭',
      '😤',
      '😩',
      '😫',
      '🥺',
      '😬',
      '😰',
      '😓',
      '🤯',
      '😳',
      '🥳',
      '😷',
    ],
  ),
  ('Hands', ['👍', '👎', '👏', '🙌', '🙏', '🤝', '👋', '✋', '👌', '✌️', '🤞', '🤟', '🤙', '👈', '👉', '👆', '👇', '☝️', '💪', '✍️', '🫡', '🫶']),
  (
    'Study',
    [
      '📚',
      '📖',
      '📝',
      '✏️',
      '🖊️',
      '📐',
      '📏',
      '🧮',
      '🔬',
      '🧪',
      '🧬',
      '⚗️',
      '🔭',
      '🌍',
      '💡',
      '🧠',
      '🎯',
      '🏆',
      '🥇',
      '📅',
      '⏰',
      '✅',
      '❌',
      '❓',
      '❗',
      '💯',
      '🎓',
      '🏫',
    ],
  ),
  ('Hearts', ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💖', '💗', '💓', '💞', '💕', '✨', '⭐', '🌟', '🔥', '🎉', '🎊', '🙌']),
];

/// "Today", "Yesterday", "Monday", "12 Nov".
String chatDay(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return _days[d.weekday - 1];
  return '${d.day} ${_months[d.month - 1]}${d.year == n.year ? '' : ' ${d.year}'}';
}

String chatTime(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
String fmtDur(num s) => '${s ~/ 60}:${(s.round() % 60).toString().padLeft(2, '0')}';
String initialsOf(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// "last seen today at 6:40 pm", "last seen yesterday at 9:02 am", "last seen 3 Nov".
String lastSeen(Object? iso, [DateTime? now]) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  final day = chatDay(d, now);
  if (day == 'Today' || day == 'Yesterday') return 'last seen ${day.toLowerCase()} at ${chatTime(d)}';
  return 'last seen $day';
}

/// Only emoji (1 to 3, with skin tones and joiners): shown big in the bubble, like WhatsApp.
bool emojiOnly(String t) {
  final s = t.trim();
  if (s.isEmpty || s.runes.length > 8) return false;
  var n = 0;
  for (final r in s.runes) {
    if (r == 0x200D || r == 0xFE0F || (r >= 0x1F3FB && r <= 0x1F3FF)) continue;
    if (r < 0x2190) return false;
    n++;
  }
  return n >= 1 && n <= 3;
}

/// Short line for a notification-style preview.
String chatPreview(ChatMsg m) => m.deleted
    ? 'This message was deleted'
    : switch (m.kind) {
        'image' => '📷 Photo',
        'voice' => '🎤 Voice note',
        'file' => '📎 ${m.meta['name'] ?? 'File'}',
        'link' => '📞 ${m.body.isEmpty ? 'Call link' : m.body}',
        'ref' => '📚 ${m.ref?['title'] ?? 'Study link'}',
        _ => m.body,
      };

/// Short label for a quoted message (the reply bar and the quote inside a bubble).
String quoteText(Map<String, dynamic> r) => r['deleted'] == true
    ? 'This message was deleted'
    : switch ('${r['kind']}') {
        'image' => 'Photo',
        'voice' => 'Voice note${r['meta'] is Map && (r['meta'] as Map)['duration'] != null ? ' (${fmtDur((r['meta'] as Map)['duration'] as num)})' : ''}',
        'file' => 'File',
        'link' => '${r['body']}'.isEmpty ? 'Call link' : '${r['body']}',
        'ref' => '${r['body']}'.isEmpty ? 'Study link' : '${r['body']}',
        _ => '${r['body']}',
      };

/// Which call service a link is, from its meta or its address: meet, whatsapp, zoom or video.
String callType(Map<String, dynamic> meta) {
  final t = '${meta['type'] ?? ''}';
  if (const {'meet', 'whatsapp', 'zoom'}.contains(t)) return t;
  final host = Uri.tryParse('${meta['url'] ?? ''}')?.host ?? '';
  if (host.contains('meet.google')) return 'meet';
  if (host.contains('zoom.us')) return 'zoom';
  if (host.contains('wa.me') || host.contains('whatsapp')) return 'whatsapp';
  return 'video';
}

/// Chat colours (light and dark), from the approved designs.
class ChatColors {
  const ChatColors._(this.dark);
  factory ChatColors.of(BuildContext context) => ChatColors._(context.isDark);
  final bool dark;
  Color get bg => dark ? const Color(0xFF081224) : const Color(0xFFEEF2F8);
  Color get header => dark ? const Color(0xFF0B1730) : Palette.navy900;
  Color get mine => dark ? const Color(0xFF1E5BB0) : Palette.navy900;
  Color get theirs => dark ? const Color(0xFF13233F) : Colors.white;
  Color get theirsText => dark ? const Color(0xFFEAF0FA) : Palette.navy900;
  Color get theirsMeta => dark ? const Color(0xFF8090AA) : const Color(0xFF6B7A93);
  Color get quote => dark ? const Color(0xFF0A1A33) : const Color(0xFFF1F4F9);
  Color get composer => dark ? const Color(0xFF13233F) : Colors.white;
  Color get chip => dark ? const Color(0xFF13233F) : Colors.white;
  Color get chipText => dark ? const Color(0xFFA7B4CA) : const Color(0xFF4A5A74);
  static const read = Color(0xFF7DD3FC);
}

class TutorChatView extends ConsumerStatefulWidget {
  const TutorChatView({super.key, required this.requestId, required this.initial, this.tutor, this.readOnly, this.footer, this.onBack, this.draft});
  final String requestId;
  final List<Map<String, dynamic>> initial;

  /// The tutor's card (null before a tutor is assigned: the chat is with the SolutionTee team).
  final Map<String, dynamic>? tutor;

  /// Shown instead of the message box (plan ended…).
  final String? readOnly;

  /// Extra widget above the message box (e.g. renew plans).
  final Widget? footer;
  final VoidCallback? onBack;

  /// Text to start the message box with ("Say hello" from the tutor reveal).
  final String? draft;
  @override
  ConsumerState<TutorChatView> createState() => _TutorChatViewState();
}

class _TutorChatViewState extends ConsumerState<TutorChatView> {
  late final _text = TextEditingController(text: widget.draft ?? '');
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late List<ChatMsg> _msgs = [for (final m in widget.initial) ChatMsg.from(m)];
  LiveChannel? _db, _room;
  ResumeWatcher? _resume;
  Timer? _poll, _typingTimer;
  bool _typing = false, _online = false, _dbLive = false, _emoji = false;
  String _peerDoing = 'typing…';
  DateTime _lastTyping = DateTime(2000);
  int _temp = -1;
  ChatMsg? _replyTo;
  int? _unreadFrom; // first unread message from the tutor when the chat opened
  int _newBelow = 0; // messages that came in while scrolled up
  bool _away = false, _loadingOlder = false, _hasOlder = true;

  // Voice recording.
  final _recorder = AudioRecorder();
  DateTime? _recStart;
  Duration _recDone = Duration.zero; // time recorded before the last pause
  bool _recLocked = false, _recPaused = false;
  Offset _recDrag = Offset.zero;
  final _levels = <double>[];
  StreamSubscription<Amplitude>? _amp;
  Timer? _recTick;

  SupabaseClient get _client => Supabase.instance.client;
  String get _peer => widget.tutor?['name'] as String? ?? 'SolutionTee';
  String get _rid => widget.requestId;

  @override
  void initState() {
    super.initState();
    _unreadFrom = _msgs.where((m) => !m.mine && m.role != 'system' && m.readAt == null).map((m) => m.id).firstOrNull;
    _scroll.addListener(_onScroll);
    _connect();
    _resume = ResumeWatcher(() {
      _db?.restart();
      _room?.restart();
      _sync();
      _markRead();
    });
    // Safety net: if the live channel is down, look for new messages every 12 s (every 60 s while it is up).
    _poll = Timer.periodic(const Duration(seconds: 12), (t) {
      if (!_dbLive || t.tick % 5 == 0) _sync();
    });
    _markRead();
    if (widget.draft != null) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void didUpdateWidget(TutorChatView old) {
    super.didUpdateWidget(old);
    _merge([for (final m in widget.initial) ChatMsg.from(m)]);
  }

  @override
  void dispose() {
    _db?.close();
    _room?.close();
    _resume?.dispose();
    _poll?.cancel();
    _typingTimer?.cancel();
    _recTick?.cancel();
    _amp?.cancel();
    _recorder.dispose();
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ live

  void _connect() {
    try {
      Supabase.instance.client;
    } catch (_) {
      return; // not set up (tests)
    }
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'request_id', value: _rid);
    // Messages (rows) on a public channel: Postgres row security decides who receives them.
    _db = LiveChannel(
      'tutor-db:$_rid',
      (ch) => ch
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tutor_messages',
          filter: filter,
          callback: (p) => _incoming(ChatMsg.from(p.newRecord)),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tutor_messages',
          filter: filter,
          callback: (p) => _merge([ChatMsg.from(p.newRecord)]),
        ),
      onUp: (_) {
        if (mounted) setState(() => _dbLive = true);
        _sync(); // anything sent while we were joining
      },
      onDown: () => mounted ? setState(() => _dbLive = false) : null,
    )..open();
    // Typing, recording and who is online, on the private room (only chat members may join it).
    _room = LiveChannel(
      'tutor:$_rid',
      private: true,
      presenceKey: 'student',
      (ch) => ch
        ..onBroadcast(
          event: 'typing',
          callback: (p) {
            if (!mounted || p['role'] == 'student') return;
            setState(() => (_typing = true, _peerDoing = p['what'] == 'voice' ? 'recording audio…' : 'typing…'));
            _typingTimer?.cancel();
            _typingTimer = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _typing = false) : null);
          },
        )
        ..onPresenceSync((_) {
          if (!mounted) return;
          final keys = {for (final s in ch.presenceState()) s.key};
          setState(() => _online = keys.contains('tutor') || (widget.tutor == null && keys.contains('admin')));
        }),
      onUp: (ch) => ch.track({'role': 'student', 'at': DateTime.now().millisecondsSinceEpoch}),
      onDown: () => mounted ? setState(() => _online = false) : null,
    )..open();
  }

  void _incoming(ChatMsg m) {
    if (!mounted) return;
    if (_msgs.any((x) => x.id == m.id)) return _merge([m]);
    setState(() {
      // Our own message coming back: it replaces the "sending" copy.
      _msgs = [..._msgs.where((x) => !(x.pending && m.mine && x.kind == m.kind && x.body == m.body)), m];
      if (m.reply == null && m.replyTo != null) m.reply = _quoteOf(m.replyTo!);
      if (!m.mine) {
        _typing = false;
        if (_away) _newBelow++;
      }
    });
    if (!m.mine) {
      _markRead();
      if (!_away) _toBottom();
    }
  }

  Map<String, dynamic>? _quoteOf(int id) {
    final o = _msgs.where((x) => x.id == id).firstOrNull;
    return o == null ? null : {'id': o.id, 'role': o.role, 'kind': o.kind, 'body': o.body, 'deleted': o.deleted, 'meta': o.meta};
  }

  /// Adds new messages and updates known ones (reactions, ticks, deletes), keeping the order by id.
  void _merge(List<ChatMsg> fresh) {
    if (!mounted || fresh.isEmpty) return;
    var changed = false;
    final byId = {for (final m in _msgs) m.id: m};
    final add = <ChatMsg>[];
    for (final n in fresh) {
      final o = byId[n.id];
      if (o != null) {
        o.update(n);
        changed = true;
      } else {
        add.add(n);
      }
    }
    if (add.isNotEmpty) {
      _msgs = [..._msgs.where((x) => !(x.pending && add.any((n) => n.mine && n.kind == x.kind && n.body == x.body))), ...add]
        ..sort((a, b) => (a.pending ? 1 << 52 : a.id).compareTo(b.pending ? 1 << 52 : b.id));
      for (final m in add) {
        if (m.reply == null && m.replyTo != null) m.reply = _quoteOf(m.replyTo!);
      }
      changed = true;
      if (add.any((m) => !m.mine)) _markRead();
    }
    if (changed) setState(() {});
  }

  /// Fetches the latest messages (missed while offline, joining or asleep).
  Future<void> _sync() async {
    try {
      final r = await _client.rpc('tutor_messages_before', params: {'p_request': _rid, 'p_before': 9007199254740991, 'p_limit': 60});
      _merge([for (final m in (r as List? ?? const [])) ChatMsg.from(Map<String, dynamic>.from(m as Map))]);
    } catch (_) {}
  }

  Future<void> _older() async {
    final oldest = _msgs.where((m) => !m.pending).map((m) => m.id).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    if (_loadingOlder || !_hasOlder || oldest == null) return;
    setState(() => _loadingOlder = true);
    try {
      final r = (await _client.rpc('tutor_messages_before', params: {'p_request': _rid, 'p_before': oldest, 'p_limit': 50})) as List? ?? const [];
      _hasOlder = r.length >= 50;
      _merge([for (final m in r) ChatMsg.from(Map<String, dynamic>.from(m as Map))]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away = _scroll.offset > 280;
    if (away != _away) setState(() => (_away = away, _newBelow = away ? _newBelow : 0));
    if (_scroll.position.maxScrollExtent - _scroll.offset < 400) _older();
  }

  Future<void> _markRead() async {
    try {
      final n = await _client.rpc('tutor_mark_read', params: {'p_request': _rid});
      if ((n as num? ?? 0) > 0 && mounted) {
        final now = DateTime.now();
        setState(() {
          for (final m in _msgs) {
            if (!m.mine) m.readAt ??= now;
          }
        });
      }
    } catch (_) {}
  }

  void _onTyping({bool voice = false}) {
    if (DateTime.now().difference(_lastTyping) < const Duration(milliseconds: 2500)) return;
    _lastTyping = DateTime.now();
    _room?.channel?.sendBroadcastMessage(event: 'typing', payload: {'role': 'student', if (voice) 'what': 'voice'});
  }

  void _say(String m, [IconData? i]) => toast(context, m, icon: i ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  // ------------------------------------------------------------ send

  Future<void> _send(String kind, String body, {Uint8List? bytes, String? contentType, Map<String, dynamic>? meta, String? localPath}) async {
    final id = _temp--;
    final reply = _replyTo;
    final temp = ChatMsg(
      id: id,
      role: 'student',
      kind: kind,
      body: body,
      at: DateTime.now(),
      meta: meta ?? const {},
      pending: true,
      localPath: localPath,
      replyTo: reply?.id,
      reply: reply == null ? null : _quoteOf(reply.id),
    );
    setState(() => (_msgs = [..._msgs, temp], _replyTo = null));
    _toBottom();
    try {
      String? key;
      if (bytes != null) {
        final (k, url) = await ref.read(apiProvider).tutorUploadLink(_rid, contentType!, bytes.length);
        final r = await http.put(Uri.parse(url), headers: {'content-type': contentType}, body: bytes).timeout(const Duration(seconds: 90));
        if (r.statusCode >= 300) throw Exception('upload');
        key = k;
      }
      final r = Map<String, dynamic>.from(
        await _client
                .rpc(
                  'tutor_message_send',
                  params: {'p_request': _rid, 'p_body': body, 'p_kind': kind, 'p_attachment': key, 'p_meta': meta, 'p_reply_to': ?reply?.id},
                )
                .timeout(const Duration(seconds: 20))
            as Map,
      );
      if (r['ok'] != true || r['message'] == null) {
        throw _SendError(switch ('${r['error']}') {
          'ended' => 'Your plan has ended. Renew it to keep chatting.',
          'too_many' => 'You have sent many messages. Please wait a little.',
          _ => 'Not sent. Tap to try again.',
        });
      }
      final m = ChatMsg.from(Map<String, dynamic>.from(r['message'] as Map));
      if (!mounted) return;
      setState(() => _msgs = _msgs.any((x) => x.id == m.id) ? _msgs.where((x) => x.id != id).toList() : [for (final x in _msgs) x.id == id ? m : x]);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => temp
          ..pending = false
          ..failed = true,
      );
      _say(e is _SendError ? e.text : 'Not sent. Check your internet.', PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: context.reduceMotion ? Duration.zero : Motion.base, curve: Curves.easeOut);
  });

  Future<void> _sendText() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    setState(() {});
    await _send('text', t);
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 80).catchError((_) => null);
    if (x == null) return;
    final bytes = await File(x.path).readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) return _say('That photo is too big.');
    await _send('image', '', bytes: bytes, contentType: 'image/jpeg', meta: {'size': bytes.length}, localPath: x.path);
  }

  // ------------------------------------------------------------ voice notes

  Duration get _recElapsed => _recDone + (_recStart != null && !_recPaused ? DateTime.now().difference(_recStart!) : Duration.zero);
  bool get _recording => _recStart != null || _recPaused;

  Future<void> _recBegin() async {
    if (_recording) return;
    try {
      if (!await _recorder.hasPermission()) return _say('Allow the microphone to send a voice note.');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050), path: path);
      HapticFeedback.mediumImpact();
      setState(() {
        _recStart = DateTime.now();
        _recDone = Duration.zero;
        _recLocked = _recPaused = false;
        _recDrag = Offset.zero;
        _levels.clear();
      });
      _amp = _recorder.onAmplitudeChanged(const Duration(milliseconds: 110)).listen((a) {
        if (!mounted || _recPaused) return;
        _levels.add(((a.current + 50) / 50).clamp(.08, 1.0));
        if (_levels.length > 60) _levels.removeAt(0);
      });
      _recTick = Timer.periodic(const Duration(milliseconds: 110), (_) {
        if (!mounted) return;
        setState(() {});
        _onTyping(voice: true);
        if (_recElapsed > const Duration(minutes: 5)) _recFinish(true);
      });
    } catch (_) {
      _say('Could not start recording.');
    }
  }

  void _recMove(Offset d) {
    if (!_recording || _recLocked) return;
    setState(() => _recDrag = Offset(d.dx.clamp(-160, 0), d.dy.clamp(-120, 0)));
    if (d.dx < -120) {
      HapticFeedback.selectionClick();
      _recFinish(false);
    } else if (d.dy < -80) {
      HapticFeedback.mediumImpact();
      setState(() => (_recLocked = true, _recDrag = Offset.zero));
    }
  }

  void _recRelease() {
    if (!_recording || _recLocked) return;
    _recFinish(true);
  }

  Future<void> _recPause() async {
    if (_recPaused) {
      await _recorder.resume().catchError((_) {});
      setState(() => (_recPaused = false, _recStart = DateTime.now()));
    } else {
      await _recorder.pause().catchError((_) {});
      setState(() => (_recDone = _recElapsed, _recPaused = true, _recStart = null));
    }
  }

  Future<void> _recFinish(bool keep) async {
    final secs = _recElapsed.inMilliseconds / 1000;
    _recTick?.cancel();
    await _amp?.cancel();
    _amp = null;
    setState(() => (_recStart = null, _recPaused = false, _recLocked = false, _recDrag = Offset.zero));
    final path = await _recorder.stop().catchError((_) => null);
    if (!keep || path == null) return;
    if (secs < 1) return _say('Hold the microphone to record, then let go to send.');
    final bytes = await File(path).readAsBytes();
    await _send('voice', '', bytes: bytes, contentType: 'audio/mp4', meta: {'duration': secs.round(), 'mime': 'audio/mp4'});
  }

  // ------------------------------------------------------------ message actions

  Future<void> _react(ChatMsg m, String e) async {
    HapticFeedback.selectionClick();
    final before = Map<String, String>.from(m.reactions);
    setState(
      () => m.reactions = {...m.reactions}
        ..update('student', (o) => o == e ? '' : e, ifAbsent: () => e)
        ..removeWhere((_, v) => v.isEmpty),
    );
    try {
      final r = await _client.rpc('tutor_message_react', params: {'p_message': m.id, 'p_emoji': e});
      if ((r as Map?)?['ok'] != true) throw Exception();
    } catch (_) {
      if (mounted) setState(() => m.reactions = before);
    }
  }

  Future<void> _star(ChatMsg m) async {
    final on = !m.starred;
    setState(() => m.starred = on);
    _say(
      on ? 'Starred. Find it in the menu: Starred messages.' : 'Removed from starred.',
      on ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.star(),
    );
    try {
      await _client.rpc('tutor_message_star', params: {'p_message': m.id, 'p_on': on});
    } catch (_) {
      if (mounted) setState(() => m.starred = !on);
    }
  }

  Future<void> _delete(ChatMsg m) async {
    final ok = await showAppDialog<bool>(
      context,
      title: 'Delete for everyone?',
      body: 'This message will be removed for you and your tutor.',
      icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
      tone: Tone.red,
      actions: [
        Btn('Delete for everyone', kind: BtnKind.danger, block: true, onPressed: () => Navigator.pop(context, true)),
        Btn('Cancel', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(context, false)),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      final r = await _client.rpc('tutor_message_delete', params: {'p_message': m.id});
      if ((r as Map?)?['ok'] != true) return _say('You can delete your own messages for 48 hours.');
      if (mounted) setState(() => (m.deleted = true, m.body = '', m.kind = 'text', m.attachment = null, m.reactions = const {}));
    } catch (_) {
      _say('Could not delete. Check your internet.');
    }
  }

  Future<void> _report(ChatMsg m) async {
    const reasons = ['Rude or bullying', 'Asked for money or to chat outside SolutionTee', 'Wrong or harmful content', 'Something else'];
    final reason = await showSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Report this message', style: ctx.ty.h2),
          const Gap(Space.s1),
          Text('Our team will look at it. Your tutor is not told who reported it.', style: ctx.ty.sm.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          ListCard(
            children: [
              for (final r in reasons) ListRow(icon: PhosphorIcons.flag(PhosphorIconsStyle.fill), tone: Tone.red, title: r, onTap: () => Navigator.pop(ctx, r)),
            ],
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _client.rpc('tutor_message_report', params: {'p_message': m.id, 'p_reason': reason});
      _say('Thank you. Our team will look at it.', PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill));
    } catch (_) {
      _say('Could not send the report. Check your internet.');
    }
  }

  void _startReply(ChatMsg m) {
    if (m.pending || m.deleted || m.role == 'system') return;
    HapticFeedback.lightImpact();
    setState(() => (_replyTo = m, _emoji = false));
    _focus.requestFocus();
  }

  Future<void> _actions(ChatMsg m) async {
    if (m.pending || m.role == 'system') return;
    HapticFeedback.mediumImpact();
    final canDelete = m.mine && !m.deleted && DateTime.now().difference(m.at) < const Duration(hours: 48);
    final pick = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: .55),
      transitionDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      transitionBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: .94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.out)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => _ActionsSheet(m: m, who: m.mine ? 'You' : (m.role == 'tutor' ? _peer : 'SolutionTee'), mine: m.mine, canDelete: canDelete),
    );
    if (pick == null || !mounted) return;
    if (pick.startsWith('react:')) return _react(m, pick.substring(6));
    switch (pick) {
      case 'more':
        final e = await showSheet<String>(context, builder: (ctx) => _EmojiGrid(onPick: (e) => Navigator.pop(ctx, e)));
        if (e != null) await _react(m, e);
      case 'reply':
        _startReply(m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.kind == 'link' ? '${m.meta['url'] ?? m.body}' : m.body));
        _say('Copied');
      case 'star':
        await _star(m);
      case 'delete':
        await _delete(m);
      case 'report':
        await _report(m);
    }
  }

  void _attach() => showSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Send', style: ctx.ty.h2),
        const Gap(Space.s4),
        Row(
          children: [
            Expanded(
              child: _AttachTile(
                icon: PhosphorIcons.image(PhosphorIconsStyle.fill),
                color: Palette.blue600,
                label: 'Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ),
            Expanded(
              child: _AttachTile(
                icon: PhosphorIcons.camera(PhosphorIconsStyle.fill),
                color: const Color(0xFFE5484D),
                label: 'Camera',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
            ),
            Expanded(
              child: _AttachTile(
                icon: PhosphorIcons.microphone(PhosphorIconsStyle.fill),
                color: Palette.green500,
                label: 'Voice note',
                onTap: () {
                  Navigator.pop(ctx);
                  _say('Hold the microphone button to record. Slide up to lock, left to cancel.', PhosphorIcons.microphone(PhosphorIconsStyle.fill));
                },
              ),
            ),
          ],
        ),
        const Gap(Space.s4),
        InfoBanner(
          icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
          child: const Text('Photos and voice notes stay private: only you, your tutor and SolutionTee can open them.'),
        ),
      ],
    ),
  );

  void _showTutor() {
    final t = widget.tutor;
    if (t == null) return;
    showSheet<void>(
      context,
      builder: (ctx) => Column(
        children: [
          TutorAvatar(name: '${t['name']}', photo: t['photo_path'] as String?, size: 84, online: _online),
          const Gap(Space.s3),
          Text('${t['name']}', style: ctx.ty.h2, textAlign: TextAlign.center),
          if ('${t['subjects'] ?? ''}'.isNotEmpty) Text('${t['subjects']}', style: ctx.ty.sm.col(ctx.c.textMuted), textAlign: TextAlign.center),
          if (t['years'] != null || '${t['qualification'] ?? ''}'.isNotEmpty) ...[
            const Gap(Space.s2),
            Text(
              [if (t['years'] != null) '${t['years']} years teaching', if ('${t['qualification'] ?? ''}'.isNotEmpty) '${t['qualification']}'].join(' · '),
              style: ctx.ty.cap.bold.col(ctx.c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if ('${t['bio'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s3), Text('${t['bio']}', style: ctx.ty.body, textAlign: TextAlign.center)],
          const Gap(Space.s4),
          InfoBanner(
            icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
            child: const Text('Keep lessons in this chat or on the call links your tutor sends. Never send money to anyone outside SolutionTee.'),
          ),
        ],
      ),
    );
  }

  Future<void> _starred() async {
    final r = await _client.rpc('tutor_starred', params: {'p_request': _rid}).catchError((_) => <dynamic>[]);
    final list = [for (final m in (r as List? ?? const [])) ChatMsg.from(Map<String, dynamic>.from(m as Map))];
    if (!mounted) return;
    showSheet<void>(
      context,
      scroll: true,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Starred messages', style: ctx.ty.h2),
          const Gap(Space.s3),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s6),
              child: Column(
                children: [
                  Icon(PhosphorIcons.star(), size: 40, color: ctx.c.textSubtle),
                  const Gap(Space.s2),
                  Text('Hold a message and tap Star to keep it here.', style: ctx.ty.sm.col(ctx.c.textMuted), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            for (final m in list)
              Container(
                margin: const EdgeInsets.only(bottom: Space.s2),
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(color: ctx.c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.mine ? 'You' : _peer} · ${chatDay(m.at)} ${chatTime(m.at)}', style: ctx.ty.cap.bold.col(ctx.c.textMuted)),
                    const Gap(4),
                    Text(chatPreview(m), style: ctx.ty.body, maxLines: 6, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    final items = _msgs.reversed.toList();
    final status = _typing
        ? _peerDoing
        : _online
        ? 'online'
        : widget.tutor == null
        ? 'SolutionTee team · replies within a day'
        : (lastSeen(widget.tutor?['last_seen_at']).isNotEmpty ? lastSeen(widget.tutor?['last_seen_at']) : '${widget.tutor?['subjects'] ?? 'Your tutor'}');
    final live = _liveClass();
    return Scaffold(
      backgroundColor: cc.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatHeader(
          name: _peer,
          photo: widget.tutor?['photo_path'] as String?,
          status: status,
          highlight: _typing || _online,
          online: _online,
          color: cc.header,
          onBack: widget.onBack ?? () => context.canPop() ? context.pop() : context.go('/study'),
          onTap: _showTutor,
          onMenu: (v) => v == 'starred' ? _starred() : _showTutor(),
          hasTutor: widget.tutor != null,
        ),
      ),
      body: Column(
        children: [
          if (live != null) _LiveClassBar(m: live, from: _peer),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _emoji ? setState(() => _emoji = false) : FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(Space.s3, Space.s3, Space.s3, Space.s3),
                    itemCount: items.length + (_typing ? 1 : 0) + 1,
                    itemBuilder: (_, i) {
                      if (_typing && i == 0) return _TypingDots(color: cc.theirs);
                      final idx = _typing ? i - 1 : i;
                      if (idx == items.length) {
                        return _loadingOlder
                            ? const Padding(
                                padding: EdgeInsets.all(Space.s3),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            : (items.isEmpty ? _EmptyChat(peer: _peer) : const SizedBox(height: Space.s2));
                      }
                      final m = items[idx];
                      final older = idx + 1 < items.length ? items[idx + 1] : null;
                      final newDay = older == null || chatDay(older.at) != chatDay(m.at);
                      final first = newDay || older.role != m.role || older.role == 'system';
                      final unreadHere = m.id == _unreadFrom;
                      return Column(
                        children: [
                          if (newDay) _DayChip(chatDay(m.at)),
                          if (unreadHere) _UnreadChip(count: _msgs.where((x) => x.id >= m.id && !x.mine).length),
                          _SwipeToReply(
                            key: ValueKey(m.id),
                            enabled: !m.pending && !m.deleted && m.role != 'system' && widget.readOnly == null,
                            onReply: () => _startReply(m),
                            child: ChatBubble(
                              m: m,
                              mine: m.mine,
                              first: first,
                              who: m.role == 'tutor' ? _peer : 'SolutionTee',
                              peer: _peer,
                              onLongPress: () => _actions(m),
                              onTap: m.failed ? null : () => _actions(m),
                              onRetry: m.failed && m.kind == 'text'
                                  ? () {
                                      setState(() => _msgs.remove(m));
                                      _send('text', m.body);
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Positioned(
                  right: Space.s3,
                  bottom: Space.s3,
                  child: AnimatedScale(
                    scale: _away ? 1 : 0,
                    duration: Motion.fast,
                    curve: Motion.out,
                    child: _ToBottomBtn(
                      count: _newBelow,
                      onTap: () {
                        _toBottom();
                        setState(() => _newBelow = 0);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          ?widget.footer,
          if (widget.readOnly != null)
            Container(
              width: double.infinity,
              color: context.c.surface,
              padding: const EdgeInsets.all(Space.s4),
              child: SafeArea(
                top: false,
                child: Text(widget.readOnly!, style: context.ty.sm.col(context.c.textMuted), textAlign: TextAlign.center),
              ),
            )
          else
            _composer(context, cc),
        ],
      ),
    );
  }

  /// The newest call link from the last 90 minutes: shown as a "Join" bar under the header.
  ChatMsg? _liveClass() {
    final now = DateTime.now();
    for (final m in _msgs.reversed) {
      if (now.difference(m.at) > const Duration(minutes: 90)) return null;
      if (m.kind == 'link' && !m.mine && !m.deleted && '${m.meta['url'] ?? ''}'.startsWith('https://')) return m;
    }
    return null;
  }

  Widget _composer(BuildContext context, ChatColors cc) {
    final c = context.c;
    final has = _text.text.trim().isNotEmpty;
    final r = _replyTo;
    return Container(
      color: cc.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: Motion.fast,
              curve: Motion.out,
              child: r == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, 0),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: cc.composer,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(left: BorderSide(color: Palette.gold400, width: 3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${r.mine ? 'yourself' : (r.role == 'tutor' ? _peer : 'SolutionTee')}',
                                  style: context.ty.cap.bold.col(context.isDark ? Palette.gold400 : Palette.gold700),
                                ),
                                Text(
                                  quoteText(_quoteOf(r.id) ?? const {}),
                                  style: context.ty.sm.col(c.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel reply',
                            onPressed: () => setState(() => _replyTo = null),
                            icon: Icon(PhosphorIcons.x(), size: 18, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, Space.s2),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: _recLocked || _recPaused
                    ? _lockedRecorder(context, cc)
                    : _recording
                    ? _holdRecorder(context, cc)
                    : Row(
                        key: const ValueKey('type'),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              decoration: BoxDecoration(color: cc.composer, borderRadius: BorderRadius.circular(24), boxShadow: context.shadow(1)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _ComposerIcon(
                                    icon: _emoji ? PhosphorIcons.keyboard() : PhosphorIcons.smiley(),
                                    label: _emoji ? 'Keyboard' : 'Emoji',
                                    onTap: () {
                                      setState(() => _emoji = !_emoji);
                                      _emoji ? FocusScope.of(context).unfocus() : _focus.requestFocus();
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _text,
                                      focusNode: _focus,
                                      minLines: 1,
                                      maxLines: 5,
                                      maxLength: 4000,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: context.ty.body,
                                      onTap: () => _emoji ? setState(() => _emoji = false) : null,
                                      decoration: InputDecoration(
                                        hintText: 'Message',
                                        hintStyle: context.ty.body.col(c.textSubtle),
                                        counterText: '',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onChanged: (_) {
                                        setState(() {});
                                        _onTyping();
                                      },
                                    ),
                                  ),
                                  _ComposerIcon(icon: PhosphorIcons.paperclip(), label: 'Send a photo', onTap: _attach),
                                  if (!has) _ComposerIcon(icon: PhosphorIcons.camera(), label: 'Take a photo', onTap: () => _pickPhoto(ImageSource.camera)),
                                ],
                              ),
                            ),
                          ),
                          const Gap(Space.s2),
                          AnimatedSwitcher(
                            duration: Motion.fast,
                            transitionBuilder: (w, a) => ScaleTransition(
                              scale: a,
                              child: RotationTransition(turns: Tween(begin: .85, end: 1.0).animate(a), child: w),
                            ),
                            child: has
                                ? _RoundBtn(
                                    key: const ValueKey('send'),
                                    icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                                    label: 'Send',
                                    onTap: _sendText,
                                  )
                                : _MicButton(key: const ValueKey('mic'), onDown: _recBegin, onMove: _recMove, onUp: _recRelease),
                          ),
                        ],
                      ),
              ),
            ),
            AnimatedSize(
              duration: Motion.fast,
              curve: Motion.out,
              child: _emoji
                  ? SizedBox(
                      height: 280,
                      child: _EmojiGrid(
                        onPick: (e) {
                          final s = _text.selection;
                          final t = _text.text;
                          final at = s.isValid ? s.start : t.length;
                          final end = s.isValid ? s.end : t.length;
                          _text.value = TextEditingValue(
                            text: t.replaceRange(at, end, e),
                            selection: TextSelection.collapsed(offset: at + e.length),
                          );
                          setState(() {});
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// Holding the microphone: timer, "slide to cancel" and the lock hint above.
  Widget _holdRecorder(BuildContext context, ChatColors cc) {
    final c = context.c;
    final rm = context.reduceMotion;
    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
    );
    return Row(
      key: const ValueKey('hold'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            decoration: BoxDecoration(color: cc.composer, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                rm ? dot : dot.animate(onPlay: (a) => a.repeat(reverse: true)).fade(begin: 1, end: .25, duration: 600.ms),
                const Gap(Space.s2),
                Text(fmtDur(_recElapsed.inMilliseconds / 1000), style: context.ty.body.tnum),
                const Spacer(),
                Transform.translate(
                  offset: Offset(_recDrag.dx * .6, 0),
                  child: Opacity(
                    opacity: (1 + _recDrag.dx / 140).clamp(.2, 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.caretLeft(), size: 16, color: c.textMuted),
                        Text('Slide to cancel', style: context.ty.sm.col(c.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(Space.s2),
        SizedBox(
          width: 56,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // The lock hint rises above the button while holding.
              Positioned(
                bottom: 64 - _recDrag.dy * .4,
                child: _LockHint(progress: (-_recDrag.dy / 80).clamp(0.0, 1.0)),
              ),
              Transform.translate(
                offset: Offset(_recDrag.dx * .25, _recDrag.dy * .25),
                child: Transform.scale(
                  scale: 1.35,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.microphone(PhosphorIconsStyle.fill), color: Palette.navy900, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Locked (hands-free) or paused: delete, timer, live wave, pause / resume, send.
  Widget _lockedRecorder(BuildContext context, ChatColors cc) {
    final c = context.c;
    return Container(
      key: const ValueKey('locked'),
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
      decoration: BoxDecoration(color: cc.composer, borderRadius: BorderRadius.circular(28), boxShadow: context.shadow(1)),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Delete recording',
            onPressed: () => _recFinish(false),
            icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill), color: c.error),
          ),
          Text(fmtDur(_recElapsed.inMilliseconds / 1000), style: context.ty.body.bold.tnum),
          const Gap(Space.s2),
          Expanded(
            child: _LiveWave(levels: _levels, paused: _recPaused),
          ),
          IconButton(
            tooltip: _recPaused ? 'Go on recording' : 'Pause',
            onPressed: _recPause,
            icon: Icon(
              _recPaused ? PhosphorIcons.microphone(PhosphorIconsStyle.fill) : PhosphorIcons.pause(PhosphorIconsStyle.fill),
              color: _recPaused ? c.error : c.textMuted,
            ),
          ),
          _RoundBtn(icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill), label: 'Send voice note', onTap: () => _recFinish(true)),
        ],
      ),
    );
  }
}

class _SendError implements Exception {
  const _SendError(this.text);
  final String text;
}

// ------------------------------------------------------------ header and bars

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.photo,
    required this.status,
    required this.highlight,
    required this.online,
    required this.color,
    required this.onBack,
    required this.onTap,
    required this.onMenu,
    required this.hasTutor,
  });
  final String name, status;
  final String? photo;
  final bool highlight, online, hasTutor;
  final Color color;
  final VoidCallback onBack, onTap;
  final void Function(String) onMenu;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: color,
      padding: EdgeInsets.only(top: top),
      height: 64 + top,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
          ),
          Expanded(
            child: InkWell(
              onTap: hasTutor ? onTap : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    TutorAvatar(name: name, photo: photo, size: 42, online: online, ring: color),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: context.ty.body.bold.col(Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          AnimatedSwitcher(
                            duration: Motion.fast,
                            transitionBuilder: (w, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a),
                                child: w,
                              ),
                            ),
                            child: Text(
                              status,
                              key: ValueKey(status),
                              style: context.ty.cap.col(highlight ? Palette.green300 : Palette.navy100),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(PhosphorIcons.dotsThreeVertical(), color: Colors.white),
            onSelected: onMenu,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'starred', child: Text('Starred messages')),
              if (hasTutor) const PopupMenuItem(value: 'info', child: Text('About my tutor')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveClassBar extends StatelessWidget {
  const _LiveClassBar({required this.m, required this.from});
  final ChatMsg m;
  final String from;
  @override
  Widget build(BuildContext context) {
    final type = callType(m.meta);
    final url = '${m.meta['url']}';
    final w = Container(
      padding: const EdgeInsets.fromLTRB(Space.s3, 8, Space.s2, 8),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF0F3B26) : Palette.green50,
        border: Border(bottom: BorderSide(color: context.c.border)),
      ),
      child: Row(
        children: [
          CallLogo(type: type, size: 26),
          const Gap(Space.s3),
          Expanded(
            child: Text(
              m.body.isEmpty ? '${callName(type)} class from $from' : m.body,
              style: context.ty.sm.bold.col(context.isDark ? Palette.green300 : Palette.green700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            style: FilledButton.styleFrom(
              backgroundColor: Palette.green500,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    return context.reduceMotion ? w : w.animate().fadeIn(duration: Motion.base).slideY(begin: -.4, end: 0, curve: Motion.out);
  }
}

class _ToBottomBtn extends StatelessWidget {
  const _ToBottomBtn({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Go to the newest message',
    child: Pressable(
      onTap: onTap,
      scale: .9,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: context.c.surface, shape: BoxShape.circle, boxShadow: context.shadow(2)),
            child: Icon(PhosphorIcons.caretDown(), color: context.c.text, size: 20),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: context.ty.cap.bold.col(Palette.navy900)),
              ),
            ),
        ],
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.peer});
  final String peer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s8, horizontal: Space.s6),
    child: Column(
      children: [
        Icon(PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill), size: 48, color: context.c.textSubtle),
        const Gap(Space.s2),
        Text('Say hello to $peer', style: context.ty.body.bold, textAlign: TextAlign.center),
        Text('Send a question, a photo of your working or a voice note.', style: context.ty.sm.col(context.c.textMuted), textAlign: TextAlign.center),
      ],
    ),
  );
}

// ------------------------------------------------------------ composer bits

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
    icon: Icon(icon, size: 22, color: context.c.textMuted),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      scale: .9,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
        child: Icon(icon, color: Palette.navy900, size: 21),
      ),
    ),
  );
}

/// Hold to record: press starts, let go sends; slide left cancels, slide up locks.
class _MicButton extends StatefulWidget {
  const _MicButton({super.key, required this.onDown, required this.onMove, required this.onUp});
  final VoidCallback onDown, onUp;
  final void Function(Offset) onMove;
  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  Offset? _start;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Hold to record a voice note',
    child: Listener(
      onPointerDown: (e) {
        _start = e.position;
        widget.onDown();
      },
      onPointerMove: (e) => _start == null ? null : widget.onMove(e.position - _start!),
      onPointerUp: (_) {
        _start = null;
        widget.onUp();
      },
      onPointerCancel: (_) {
        _start = null;
        widget.onUp();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
        child: Icon(PhosphorIcons.microphone(PhosphorIconsStyle.fill), color: Palette.navy900, size: 22),
      ),
    ),
  );
}

class _LockHint extends StatelessWidget {
  const _LockHint({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), boxShadow: context.shadow(2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(progress > .9 ? PhosphorIcons.lockSimple(PhosphorIconsStyle.fill) : PhosphorIcons.lockSimpleOpen(), size: 18, color: c.text),
          const Gap(4),
          Icon(
            PhosphorIcons.caretUp(),
            size: 14,
            color: c.textMuted,
          ).animate(onPlay: (a) => context.reduceMotion ? null : a.repeat(reverse: true)).moveY(begin: 2, end: -2, duration: 600.ms),
        ],
      ),
    );
  }
}

/// The live microphone level while recording (newest on the right).
class _LiveWave extends StatelessWidget {
  const _LiveWave({required this.levels, required this.paused});
  final List<double> levels;
  final bool paused;
  @override
  Widget build(BuildContext context) {
    final col = paused ? context.c.textSubtle : context.c.text;
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (_, box) {
          final n = (box.maxWidth / 5).floor().clamp(1, 60);
          final shown = levels.length >= n ? levels.sublist(levels.length - n) : [...List.filled(n - levels.length, .08), ...levels];
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final l in shown)
                Container(
                  width: 3,
                  height: math.max(3, 28 * l),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      scale: .94,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s2),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const Gap(Space.s2),
            Text(label, style: context.ty.sm.bold),
          ],
        ),
      ),
    ),
  );
}

class _EmojiGrid extends StatefulWidget {
  const _EmojiGrid({required this.onPick});
  final void Function(String) onPick;
  @override
  State<_EmojiGrid> createState() => _EmojiGridState();
}

class _EmojiGridState extends State<_EmojiGrid> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.surface,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (final (i, g) in emojiGroups.indexed)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: i == _tab ? Palette.gold400 : Colors.transparent, width: 2)),
                        ),
                        child: Text(g.$1, style: context.ty.cap.bold.col(i == _tab ? c.text : c.textMuted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 236,
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.all(Space.s2),
              children: [
                for (final e in emojiGroups[_tab].$2)
                  InkResponse(
                    onTap: () => widget.onPick(e),
                    radius: 22,
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ the long-press menu

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet({required this.m, required this.who, required this.mine, required this.canDelete});
  final ChatMsg m;
  final String who;
  final bool mine, canDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final my = m.reactions['student'];
    Widget item(String v, IconData i, String t, {bool danger = false}) => InkWell(
      onTap: () => Navigator.pop(context, v),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        child: Row(
          children: [
            Expanded(child: Text(t, style: context.ty.body.col(danger ? c.error : c.text))),
            Icon(i, size: 20, color: danger ? c.error : c.textMuted),
          ],
        ),
      ),
    );
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!m.deleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28), boxShadow: context.shadow(3)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, e) in quickReactions.indexed)
                          _ReactBtn(e: e, on: my == e, delay: rm ? 0 : 30 * i, onTap: () => Navigator.pop(context, 'react:$e')),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'More emoji',
                            onPressed: () => Navigator.pop(context, 'more'),
                            icon: Icon(PhosphorIcons.plus(), size: 18, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Gap(Space.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: IgnorePointer(
                      child: ChatBubble(m: m, mine: mine, first: true, who: who, peer: who, still: true),
                    ),
                  ),
                ),
                const Gap(Space.s3),
                Container(
                  width: 240,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), boxShadow: context.shadow(3)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!m.deleted) item('reply', PhosphorIcons.arrowBendUpLeft(), 'Reply'),
                      if (!m.deleted && (m.kind == 'text' || m.kind == 'link')) item('copy', PhosphorIcons.copy(), 'Copy'),
                      if (!m.deleted)
                        item('star', m.starred ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.star(), m.starred ? 'Unstar' : 'Star'),
                      if (canDelete) item('delete', PhosphorIcons.trash(), 'Delete for everyone', danger: true),
                      if (!mine && !m.deleted) item('report', PhosphorIcons.flag(), 'Report', danger: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactBtn extends StatelessWidget {
  const _ReactBtn({required this.e, required this.on, required this.delay, required this.onTap});
  final String e;
  final bool on;
  final int delay;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final w = Semantics(
      button: true,
      label: 'React $e',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? context.c.surfaceSunken : null, shape: BoxShape.circle),
          child: Text(e, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
    return delay == 0 && context.reduceMotion ? w : w.animate().scaleXY(begin: .3, end: 1, delay: delay.ms, duration: 260.ms, curve: Curves.easeOutBack);
  }
}

// ------------------------------------------------------------ list bits

class _DayChip extends StatelessWidget {
  const _DayChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 5),
        decoration: BoxDecoration(color: cc.chip, borderRadius: BorderRadius.circular(10), boxShadow: cc.dark ? null : context.shadow(1)),
        child: Text(text, style: context.ty.cap.bold.col(cc.chipText)),
      ),
    );
  }
}

class _UnreadChip extends StatelessWidget {
  const _UnreadChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s2),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Palette.gold400.withValues(alpha: .16),
      alignment: Alignment.center,
      child: Text('$count unread message${count == 1 ? '' : 's'}', style: context.ty.cap.bold.col(context.isDark ? Palette.gold300 : Palette.gold700)),
    ),
  );
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: Space.s2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
                  )
                  .animate(onPlay: (a) => a.repeat())
                  .moveY(begin: 0, end: -4, delay: (150 * i).ms, duration: 300.ms, curve: Curves.easeOut)
                  .then()
                  .moveY(begin: -4, end: 0, duration: 300.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: Motion.fast);
  }
}

/// Drag a message to the right to reply (a reply arrow appears; a small buzz when far enough).
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({super.key, required this.child, required this.onReply, this.enabled = true});
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> with SingleTickerProviderStateMixin {
  static const _trigger = 64.0;
  late final _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _dx = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _dx = _dx * (1 - _back.value)));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final p = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: (_) => _back.stop(),
      onHorizontalDragUpdate: (d) {
        final next = (_dx + d.delta.dx * (_dx > _trigger ? .3 : 1)).clamp(0.0, 96.0);
        if (!_armed && next >= _trigger) {
          _armed = true;
          HapticFeedback.lightImpact();
        } else if (_armed && next < _trigger) {
          _armed = false;
        }
        setState(() => _dx = next);
      },
      onHorizontalDragEnd: (_) {
        if (_armed) widget.onReply();
        _armed = false;
        _back.forward(from: 0);
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 4,
            child: Opacity(
              opacity: p,
              child: Transform.scale(
                scale: .6 + .4 * p,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: context.c.surface, shape: BoxShape.circle, boxShadow: context.shadow(1)),
                  child: Icon(PhosphorIcons.arrowBendUpLeft(), size: 17, color: context.c.text),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ avatar and logos

/// Initials in a circle (gold, like the designs), the tutor's photo over them, and a green dot when online.
class TutorAvatar extends StatelessWidget {
  const TutorAvatar({super.key, required this.name, this.photo, this.size = 44, this.online = false, this.ring});
  final String name;
  final String? photo;
  final double size;
  final bool online;
  final Color? ring;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.gold400),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(initialsOf(name), style: context.ty.body.bold.col(Palette.navy900).copyWith(fontSize: size * .34, height: 1)),
              ),
              if (photo != null && photo!.isNotEmpty) R2Image(imageKey: photo!, decodeWidth: (size * 3).round(), semanticLabel: name),
            ],
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: math.max(10, size * .26),
              height: math.max(10, size * .26),
              decoration: BoxDecoration(
                color: Palette.green500,
                shape: BoxShape.circle,
                border: Border.all(color: ring ?? context.c.surface, width: 2),
              ),
            ),
          ),
      ],
    ),
  );
}

String callName(String type) => switch (type) {
  'meet' => 'Google Meet',
  'whatsapp' => 'WhatsApp',
  'zoom' => 'Zoom',
  _ => 'Video',
};

/// The real Google Meet, WhatsApp and Zoom marks (assets/third_party, D-153); a plain video icon for anything else.
class CallLogo extends StatelessWidget {
  const CallLogo({super.key, required this.type, this.size = 44});
  final String type;
  final double size;
  @override
  Widget build(BuildContext context) => switch (type) {
    'meet' => Image.asset('assets/third_party/google_meet.png', width: size, height: size, fit: BoxFit.contain, semanticLabel: 'Google Meet'),
    'whatsapp' => Image.asset('assets/third_party/whatsapp.png', width: size, height: size, fit: BoxFit.contain, semanticLabel: 'WhatsApp'),
    'zoom' => Container(
      width: size * 1.3,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .22)),
      padding: EdgeInsets.symmetric(horizontal: size * .12),
      child: Image.asset('assets/third_party/zoom.png', fit: BoxFit.contain, semanticLabel: 'Zoom'),
    ),
    _ => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Palette.blue600, shape: BoxShape.circle),
      child: Icon(PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), color: Colors.white, size: size * .5),
    ),
  };
}

// ------------------------------------------------------------ the bubble

/// One message bubble. Mine (the student's) on the right in blue; the tutor's on the left.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.m,
    required this.mine,
    required this.first,
    required this.who,
    this.peer,
    this.onRetry,
    this.onLongPress,
    this.onTap,
    this.still = false,
  });
  final ChatMsg m;
  final bool mine, first;
  final String who;
  final String? peer;
  final VoidCallback? onRetry, onLongPress, onTap;

  /// No entrance animation (the copy in the long-press menu).
  final bool still;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cc = ChatColors.of(context);
    if (m.role == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s2, horizontal: Space.s4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Text(m.body, style: context.ty.cap.col(c.onAccentSoft), textAlign: TextAlign.center),
        ),
      );
    }
    final fg = mine ? Colors.white : cc.theirsText;
    final meta = mine ? Colors.white.withValues(alpha: .75) : cc.theirsMeta;
    final media = !m.deleted && (m.kind == 'image' || m.kind == 'link' || m.kind == 'ref');
    final r = m.reply;
    final body = m.deleted
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.prohibit(), size: 16, color: meta),
              const Gap(6),
              Flexible(
                child: Text(
                  mine ? 'You deleted this message' : 'This message was deleted',
                  style: context.ty.body.col(meta).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          )
        : switch (m.kind) {
            'image' => _Photo(m: m),
            'voice' => _Voice(m: m, mine: mine),
            'file' => _FileCard(m: m, mine: mine),
            'link' => _CallCard(m: m, mine: mine, from: peer ?? who),
            'ref' => _RefCard(m: m, mine: mine),
            _ => _LinkText(m.body, style: context.ty.body.col(fg).copyWith(height: 1.38), linkColor: mine ? Palette.gold300 : c.link),
          };
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: math.min(MediaQuery.sizeOf(context).width * .8, 340)),
      margin: EdgeInsets.only(top: first ? Space.s2 : 2),
      padding: media ? const EdgeInsets.all(5) : const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: mine ? cc.mine : cc.theirs,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!mine && first ? 6 : 18),
          topRight: Radius.circular(mine && first ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: cc.dark ? null : [BoxShadow(color: Palette.navy900.withValues(alpha: .08), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine && first && m.role == 'admin')
            Padding(
              padding: EdgeInsets.only(bottom: 2, left: media ? 6 : 0, top: media ? 2 : 0),
              child: Text(who, style: context.ty.cap.bold.col(cc.dark ? Palette.gold400 : Palette.blue600)),
            ),
          if (r != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: mine ? Colors.white.withValues(alpha: .14) : cc.quote,
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: Palette.gold400, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r['role'] == 'student' ? 'You' : (r['role'] == 'tutor' ? (peer ?? who) : 'SolutionTee'),
                    style: context.ty.cap.bold.col(mine ? Palette.gold300 : (cc.dark ? Palette.gold400 : Palette.blue600)),
                  ),
                  Text(
                    quoteText(r),
                    style: context.ty.sm.col(mine ? Colors.white.withValues(alpha: .85) : cc.theirsMeta),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          body,
          Padding(
            padding: media ? const EdgeInsets.fromLTRB(6, 3, 4, 1) : const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.starred) ...[Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 11, color: meta), const SizedBox(width: 4)],
                Text(chatTime(m.at), style: context.ty.cap.tnum.col(meta).copyWith(fontSize: 11)),
                if (mine && !m.deleted) ...[const SizedBox(width: 4), _Ticks(m: m, color: meta)],
              ],
            ),
          ),
        ],
      ),
    );
    final reactions = m.reactions.values.toList();
    final withReactions = reactions.isEmpty
        ? bubble
        : Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble,
              Transform.translate(
                offset: const Offset(0, -6),
                child: Padding(
                  padding: EdgeInsets.only(left: mine ? 0 : 10, right: mine ? 10 : 0),
                  child: _ReactionChip(emojis: reactions, still: still),
                ),
              ),
            ],
          );
    final row = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(onTap: onRetry ?? onTap, onLongPress: onLongPress, child: withReactions),
    );
    if (still || context.reduceMotion) return row;
    return row
        .animate()
        .fadeIn(duration: 220.ms)
        .slideX(begin: mine ? .06 : -.06, end: 0, curve: Curves.easeOut)
        .scaleXY(begin: .96, end: 1, duration: 220.ms, curve: Curves.easeOut);
  }
}

class _Ticks extends StatelessWidget {
  const _Ticks({required this.m, required this.color});
  final ChatMsg m;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (m.failed) return Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), size: 14, color: Palette.gold300);
    if (m.pending) return Icon(PhosphorIcons.clock(), size: 13, color: color);
    final read = m.readAt != null;
    final w = Icon(
      read ? PhosphorIcons.checks() : PhosphorIcons.check(),
      key: ValueKey(read),
      size: 16,
      color: read ? ChatColors.read : color,
      semanticLabel: read ? 'Seen' : 'Sent',
    );
    return AnimatedSwitcher(
      duration: Motion.fast,
      transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
      child: w,
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.emojis, required this.still});
  final List<String> emojis;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    final unique = emojis.toSet().toList();
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: cc.theirs,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cc.bg, width: 2),
        boxShadow: cc.dark ? null : context.shadow(1),
      ),
      child: Text('${unique.join()}${emojis.length > 1 ? ' ${emojis.length}' : ''}', style: context.ty.sm.col(cc.theirsText)),
    );
    return still || context.reduceMotion ? w : w.animate(key: ValueKey(emojis.join())).scaleXY(begin: .4, end: 1, duration: 280.ms, curve: Curves.easeOutBack);
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.style, required this.linkColor});
  final String text;
  final TextStyle style;
  final Color linkColor;
  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'https://[^\s<>"]+').allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final url = m.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Text(
              url,
              style: style.copyWith(color: linkColor, decoration: TextDecoration.underline, decorationColor: linkColor),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    // Only emoji (up to 3): shown big, like WhatsApp.
    final big = spans.length == 1 && emojiOnly(text);
    return Text.rich(TextSpan(style: big ? style.copyWith(fontSize: 38, height: 1.2) : style, children: spans));
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.m});
  final ChatMsg m;
  @override
  Widget build(BuildContext context) {
    final w = math.min(MediaQuery.sizeOf(context).width * .64, 280.0);
    final img = m.localPath != null
        ? Image.file(File(m.localPath!), fit: BoxFit.cover, width: w, height: w * .8)
        : m.attachment != null
        ? SizedBox(
            width: w,
            height: w * .8,
            child: R2Image(imageKey: m.attachment!, semanticLabel: 'Photo in the chat'),
          )
        : const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onTap: m.attachment == null
            ? null
            : () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
                    body: InteractiveViewer(
                      child: Center(
                        child: Hero(
                          tag: 'tphoto-${m.id}',
                          child: R2Image(imageKey: m.attachment!, fit: BoxFit.contain, decodeWidth: 1600, semanticLabel: 'Photo'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        child: Stack(
          children: [
            Hero(tag: 'tphoto-${m.id}', child: img),
            if (m.pending)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Voice note: play / pause, a wave that fills while it plays, the time and the speed (1x, 1.5x, 2x).
class _Voice extends ConsumerStatefulWidget {
  const _Voice({required this.m, required this.mine});
  final ChatMsg m;
  final bool mine;
  @override
  ConsumerState<_Voice> createState() => _VoiceState();
}

class _VoiceState extends ConsumerState<_Voice> {
  VideoPlayerController? _vc;
  bool _loading = false;
  double _speed = 1;
  late final List<double> _bars = [for (var i = 0; i < 28; i++) .3 + .7 * (((i * 7 + widget.m.id.abs()) % 11) / 10)];

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_vc != null) {
      _vc!.value.isPlaying ? await _vc!.pause() : await _vc!.play();
      return;
    }
    if (widget.m.attachment == null) return;
    setState(() => _loading = true);
    try {
      final url = await ref.read(apiProvider).signImage(widget.m.attachment!);
      final vc = VideoPlayerController.networkUrl(Uri.parse(url));
      await vc.initialize();
      vc.addListener(() {
        if (mounted) setState(() {});
        if (vc.value.position >= vc.value.duration && !vc.value.isPlaying) vc.seekTo(Duration.zero);
      });
      await vc.setPlaybackSpeed(_speed);
      setState(() => _vc = vc);
      await vc.play();
    } catch (_) {
      if (mounted) toast(context, 'Could not play this voice note.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nextSpeed() async {
    final s = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0);
    setState(() => _speed = s);
    await _vc?.setPlaybackSpeed(s);
  }

  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    final v = _vc?.value;
    final total = v != null && v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds / 1000 : (widget.m.meta['duration'] as num?)?.toDouble() ?? 0;
    final pos = v?.position.inMilliseconds ?? 0;
    final frac = total > 0 ? (pos / 1000 / total).clamp(0.0, 1.0) : 0.0;
    final on = widget.mine ? Colors.white : (cc.dark ? const Color(0xFFEAF0FA) : Palette.navy900);
    final playing = v?.isPlaying == true;
    return SizedBox(
      width: 236,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? 'Pause voice note' : 'Play voice note',
            child: InkResponse(
              onTap: widget.m.pending ? null : _toggle,
              radius: 26,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.mine ? Colors.white.withValues(alpha: .2) : Palette.blue600, shape: BoxShape.circle),
                child: _loading || widget.m.pending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(playing ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill), size: 17, color: Colors.white),
              ),
            ),
          ),
          const Gap(Space.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      for (var i = 0; i < _bars.length; i++)
                        Expanded(
                          child: Center(
                            child: AnimatedContainer(
                              duration: Motion.fast,
                              width: 3,
                              height: 26 * _bars[i],
                              decoration: BoxDecoration(
                                color: i / _bars.length <= frac && (playing || pos > 0)
                                    ? (widget.mine ? Palette.gold300 : Palette.blue400)
                                    : on.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  fmtDur(playing || pos > 0 ? pos / 1000 : total),
                  style: context.ty.cap.tnum.col(widget.mine ? Colors.white.withValues(alpha: .8) : cc.theirsMeta),
                ),
              ],
            ),
          ),
          const Gap(6),
          Semantics(
            button: true,
            label: 'Playback speed',
            child: InkResponse(
              onTap: _nextSpeed,
              radius: 22,
              child: Container(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 26),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: on.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                child: Text('${_speed == 1.5 ? '1.5' : _speed.toStringAsFixed(0)}x', style: context.ty.cap.bold.col(on)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends ConsumerWidget {
  const _FileCard({required this.m, required this.mine});
  final ChatMsg m;
  final bool mine;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = ChatColors.of(context);
    return InkWell(
      onTap: m.attachment == null
          ? null
          : () async {
              try {
                final url = await ref.read(apiProvider).signImage(m.attachment!);
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) toast(context, 'Could not open the file.');
              }
            },
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(Space.s2),
        decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .12) : cc.quote, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(8)),
              child: Icon(PhosphorIcons.filePdf(PhosphorIconsStyle.fill), color: Colors.white),
            ),
            const Gap(Space.s2),
            Expanded(
              child: Text(
                '${m.meta['name'] ?? 'Document.pdf'}',
                style: context.ty.sm.bold.col(mine ? Colors.white : cc.theirsText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A call link from the tutor: the service's real logo, the title, and a "Join with …" button in its colour.
class _CallCard extends StatelessWidget {
  const _CallCard({required this.m, required this.mine, required this.from});
  final ChatMsg m;
  final bool mine;
  final String from;
  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    final type = callType(m.meta);
    final name = callName(type);
    final color = switch (type) {
      'whatsapp' => const Color(0xFF1FAF5A),
      'meet' => const Color(0xFF1A73E8),
      'zoom' => const Color(0xFF0B5CFF),
      _ => Palette.blue600,
    };
    final url = '${m.meta['url'] ?? ''}';
    return Container(
      width: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: .12) : cc.quote, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.s3),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: CallLogo(type: type, size: type == 'zoom' ? 26 : 32),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.body.isEmpty ? '$name call' : m.body, style: context.ty.sm.bold.col(mine ? Colors.white : cc.theirsText), maxLines: 2),
                      Text(
                        '$name · ${mine ? 'from you' : 'from ${from.split(' ').first}'}',
                        style: context.ty.cap.col(mine ? Colors.white.withValues(alpha: .8) : cc.theirsMeta),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: color,
            child: InkWell(
              onTap: url.startsWith('https://') ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text('Join with $name', style: context.ty.sm.bold.col(Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefCard extends StatelessWidget {
  const _RefCard({required this.m, required this.mine});
  final ChatMsg m;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final cc = ChatColors.of(context);
    final r = m.ref ?? const {};
    final pq = r['type'] == 'pq';
    return InkWell(
      onTap: () {
        if (pq) {
          context.push('/study/pq/${r['exam_id']}/${r['subject_id']}/${r['year']}');
        } else if (r['id'] != null) {
          context.push(studyPath('${r['kind'] ?? 'note'}', '${r['id']}'));
        }
      },
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: .12) : cc.quote,
          borderRadius: BorderRadius.circular(13),
          border: const Border(left: BorderSide(color: Palette.gold400, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pq ? PhosphorIcons.exam(PhosphorIconsStyle.fill) : PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
                  size: 14,
                  color: cc.dark || mine ? Palette.gold400 : Palette.gold700,
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    '${r['title'] ?? 'Study link'}'.toUpperCase(),
                    style: context.ty.cap.bold.col(cc.dark || mine ? Palette.gold400 : Palette.gold700).copyWith(letterSpacing: .4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if ('${r['snippet'] ?? ''}'.isNotEmpty) ...[
              const Gap(4),
              Text('${r['snippet']}', style: context.ty.sm.col(mine ? Colors.white : cc.theirsText), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const Gap(6),
            Text(
              pq ? 'Past question · tap to open' : 'Lesson · tap to open',
              style: context.ty.cap.bold.col(mine ? Colors.white.withValues(alpha: .85) : Palette.blue400),
            ),
          ],
        ),
      ),
    );
  }
}
