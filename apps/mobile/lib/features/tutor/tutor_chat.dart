import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

// The student's chat with their tutor (D-152): live (Supabase Realtime), WhatsApp-like bubbles, photos, voice notes,
// call cards (Meet / WhatsApp / Zoom), study links that open in the app, read ticks, "online" and "typing…".

/// One chat message, as tutor_overview / tutor_message_send / the table row send it.
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
  });
  final int id;
  final String role, kind, body;
  final String? attachment, localPath;
  final DateTime at;
  DateTime? readAt;
  final Map<String, dynamic> meta;
  final Map<String, dynamic>? ref;
  bool pending, failed;

  factory ChatMsg.from(Map<String, dynamic> j) => ChatMsg(
    id: (j['id'] as num).toInt(),
    role: '${j['role'] ?? j['sender_role'] ?? 'student'}',
    kind: '${j['kind'] ?? 'text'}',
    body: '${j['body'] ?? ''}',
    attachment: (j['attachment'] ?? j['attachment_path']) as String?,
    at: DateTime.tryParse('${j['at'] ?? j['created_at']}')?.toLocal() ?? DateTime.now(),
    readAt: DateTime.tryParse('${j['read_at'] ?? ''}')?.toLocal(),
    meta: j['meta'] is Map ? Map<String, dynamic>.from(j['meta'] as Map) : const {},
    ref: j['ref'] is Map ? Map<String, dynamic>.from(j['ref'] as Map) : null,
  );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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

/// Short line for a notification-style preview.
String chatPreview(ChatMsg m) => switch (m.kind) {
  'image' => '📷 Photo',
  'voice' => '🎤 Voice note',
  'file' => '📎 ${m.meta['name'] ?? 'File'}',
  'link' => '📞 ${m.body.isEmpty ? 'Call link' : m.body}',
  'ref' => '📚 ${m.ref?['title'] ?? 'Study link'}',
  _ => m.body,
};

class TutorChatView extends ConsumerStatefulWidget {
  const TutorChatView({super.key, required this.requestId, required this.initial, this.tutor, this.readOnly, this.footer, this.onBack});
  final String requestId;
  final List<Map<String, dynamic>> initial;

  /// The tutor's card (null before a tutor is assigned: the chat is with the SolutionTee team).
  final Map<String, dynamic>? tutor;

  /// Shown instead of the message box (plan ended…).
  final String? readOnly;

  /// Extra widget above the message box (e.g. renew plans).
  final Widget? footer;
  final VoidCallback? onBack;
  @override
  ConsumerState<TutorChatView> createState() => _TutorChatViewState();
}

class _TutorChatViewState extends ConsumerState<TutorChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late List<ChatMsg> _msgs = [for (final m in widget.initial) ChatMsg.from(m)];
  RealtimeChannel? _ch;
  bool _typing = false, _online = false;
  Timer? _typingTimer;
  DateTime _lastTyping = DateTime(2000);
  int _temp = -1;
  final _recorder = AudioRecorder();
  DateTime? _recStart;
  Timer? _recTick;

  SupabaseClient get _db => Supabase.instance.client;
  String get _peer => widget.tutor?['name'] as String? ?? 'SolutionTee';

  @override
  void initState() {
    super.initState();
    _subscribe();
    _markRead();
  }

  @override
  void didUpdateWidget(TutorChatView old) {
    super.didUpdateWidget(old);
    // A refresh of the overview brings messages we may have missed while offline.
    final known = {for (final m in _msgs) m.id};
    final fresh = [
      for (final m in widget.initial)
        if (!known.contains((m['id'] as num).toInt())) ChatMsg.from(m),
    ];
    if (fresh.isNotEmpty) setState(() => _msgs = [..._msgs.where((m) => !m.pending), ...fresh]..sort((a, b) => a.id.compareTo(b.id)));
  }

  @override
  void dispose() {
    if (_ch != null) _db.removeChannel(_ch!);
    _typingTimer?.cancel();
    _recTick?.cancel();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _subscribe() {
    final id = widget.requestId;
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'request_id', value: id);
    _ch = _db.channel('tutor:$id', opts: const RealtimeChannelConfig(private: true, key: 'student'))
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'tutor_messages',
        filter: filter,
        callback: (p) {
          final m = ChatMsg.from(p.newRecord);
          if (!mounted || _msgs.any((x) => x.id == m.id)) return;
          setState(() {
            _msgs = [..._msgs.where((x) => !(x.pending && m.role == 'student' && x.kind == m.kind && x.body == m.body)), m];
            if (m.role != 'student') _typing = false;
          });
          if (m.role != 'student') _markRead();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'tutor_messages',
        filter: filter,
        callback: (p) {
          final m = ChatMsg.from(p.newRecord);
          if (!mounted) return;
          setState(() {
            for (final x in _msgs) {
              if (x.id == m.id) x.readAt = m.readAt;
            }
          });
        },
      )
      ..onBroadcast(
        event: 'typing',
        callback: (p) {
          if (!mounted || p['role'] == 'student') return;
          setState(() => _typing = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _typing = false) : null);
        },
      )
      ..onPresenceSync((_) {
        if (!mounted) return;
        final keys = {for (final s in _ch!.presenceState()) s.key};
        setState(() => _online = keys.contains('tutor'));
      })
      ..subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) _ch?.track({'role': 'student', 'at': DateTime.now().millisecondsSinceEpoch});
      });
  }

  Future<void> _markRead() async {
    try {
      final n = await _db.rpc('tutor_mark_read', params: {'p_request': widget.requestId});
      if ((n as num? ?? 0) > 0 && mounted) {
        final now = DateTime.now();
        setState(() {
          for (final m in _msgs) {
            if (m.role != 'student') m.readAt ??= now;
          }
        });
      }
    } catch (_) {}
  }

  void _onTyping() {
    if (DateTime.now().difference(_lastTyping) < const Duration(milliseconds: 2500)) return;
    _lastTyping = DateTime.now();
    _ch?.sendBroadcastMessage(event: 'typing', payload: {'role': 'student'});
  }

  void _say(String m, [IconData? i]) => toast(context, m, icon: i ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _send(String kind, String body, {Uint8List? bytes, String? contentType, Map<String, dynamic>? meta, String? localPath}) async {
    final id = _temp--;
    final temp = ChatMsg(id: id, role: 'student', kind: kind, body: body, at: DateTime.now(), meta: meta ?? const {}, pending: true, localPath: localPath);
    setState(() => _msgs = [..._msgs, temp]);
    _toBottom();
    try {
      String? key;
      if (bytes != null) {
        final (k, url) = await ref.read(apiProvider).tutorUploadLink(widget.requestId, contentType!, bytes.length);
        final r = await http.put(Uri.parse(url), headers: {'content-type': contentType}, body: bytes).timeout(const Duration(seconds: 90));
        if (r.statusCode >= 300) throw Exception('upload');
        key = k;
      }
      final r = Map<String, dynamic>.from(
        await _db
                .rpc('tutor_message_send', params: {'p_request': widget.requestId, 'p_body': body, 'p_kind': kind, 'p_attachment': key, 'p_meta': meta})
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

  Future<void> _startRec() async {
    try {
      if (!await _recorder.hasPermission()) return _say('Allow the microphone to send a voice note.');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050), path: path);
      setState(() => _recStart = DateTime.now());
      _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() {});
        if (DateTime.now().difference(_recStart!) > const Duration(minutes: 3)) _stopRec(true);
      });
    } catch (_) {
      _say('Could not start recording.');
    }
  }

  Future<void> _stopRec(bool keep) async {
    final start = _recStart;
    _recTick?.cancel();
    setState(() => _recStart = null);
    final path = await _recorder.stop().catchError((_) => null);
    if (!keep || path == null || start == null) return;
    final secs = DateTime.now().difference(start).inMilliseconds / 1000;
    if (secs < 1) return _say('Hold on a little longer to record.');
    final bytes = await File(path).readAsBytes();
    await _send('voice', '', bytes: bytes, contentType: 'audio/mp4', meta: {'duration': secs.round(), 'mime': 'audio/mp4'});
  }

  void _attach() => showSheet<void>(
    context,
    builder: (ctx) => ListCard(
      children: [
        ListRow(
          icon: PhosphorIcons.camera(PhosphorIconsStyle.fill),
          title: 'Camera',
          caption: 'Snap your question or your working',
          onTap: () {
            Navigator.pop(ctx);
            _pickPhoto(ImageSource.camera);
          },
        ),
        ListRow(
          icon: PhosphorIcons.image(PhosphorIconsStyle.fill),
          tone: Tone.blue,
          title: 'Gallery',
          onTap: () {
            Navigator.pop(ctx);
            _pickPhoto(ImageSource.gallery);
          },
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
          _Avatar(name: '${t['name']}', size: 84, online: _online),
          const Gap(Space.s3),
          Text('${t['name']}', style: ctx.ty.h2, textAlign: TextAlign.center),
          if ('${t['subjects'] ?? ''}'.isNotEmpty) Text('${t['subjects']}', style: ctx.ty.sm.col(ctx.c.textMuted), textAlign: TextAlign.center),
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _msgs.reversed.toList();
    final subtitle = _typing
        ? 'typing…'
        : _online
        ? 'online'
        : widget.tutor == null
        ? 'SolutionTee team · replies within a day'
        : '${widget.tutor?['subjects'] ?? 'Your tutor'}';
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: widget.onBack ?? () => context.canPop() ? context.pop() : context.go('/study'),
        ),
        title: InkWell(
          onTap: _showTutor,
          child: Row(
            children: [
              _Avatar(name: _peer, size: 40, online: _online, onDark: true),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_peer, style: context.ty.body.bold.col(c.onPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      child: Text(
                        subtitle,
                        key: ValueKey(subtitle),
                        style: context.ty.cap.col(_typing || _online ? c.accent : c.onPrimary.withValues(alpha: .75)),
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
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: context.isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2)),
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(Space.s3, Space.s3, Space.s3, Space.s3),
                itemCount: items.length + (_typing ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_typing && i == 0) return const _TypingDots();
                  final idx = _typing ? i - 1 : i;
                  final m = items[idx];
                  final older = idx + 1 < items.length ? items[idx + 1] : null;
                  final newDay = older == null || chatDay(older.at) != chatDay(m.at);
                  final first = newDay || older.role != m.role;
                  return Column(
                    children: [
                      if (newDay) _DayChip(chatDay(m.at)),
                      ChatBubble(
                        key: ValueKey(m.id),
                        m: m,
                        mine: m.role == 'student',
                        first: first,
                        who: m.role == 'tutor' ? _peer : 'SolutionTee',
                        onRetry: m.failed && m.kind == 'text'
                            ? () {
                                setState(() => _msgs.remove(m));
                                _send('text', m.body);
                              }
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          ?widget.footer,
          if (widget.readOnly != null)
            Container(
              width: double.infinity,
              color: c.surface,
              padding: const EdgeInsets.all(Space.s4),
              child: SafeArea(
                top: false,
                child: Text(widget.readOnly!, style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
              ),
            )
          else
            _composer(context),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final c = context.c;
    final recording = _recStart != null;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, Space.s2),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: Motion.fast,
          child: recording
              ? Row(
                  key: const ValueKey('rec'),
                  children: [
                    IconBtn(PhosphorIcons.trash(PhosphorIconsStyle.fill), label: 'Delete recording', onPressed: () => _stopRec(false)),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
                    ).animate(onPlay: (a) => a.repeat(reverse: true)).fade(begin: 1, end: .25, duration: 700.ms),
                    const Gap(Space.s2),
                    Expanded(child: Text('${fmtDur(DateTime.now().difference(_recStart!).inMilliseconds / 1000)}  Recording…', style: context.ty.body.tnum)),
                    _RoundBtn(icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill), label: 'Send voice note', onTap: () => _stopRec(true)),
                  ],
                )
              : Row(
                  key: const ValueKey('type'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconBtn(PhosphorIcons.paperclip(), label: 'Send a photo', onPressed: _attach),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          style: context.ty.body,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _onTyping();
                          },
                        ),
                      ),
                    ),
                    const Gap(Space.s2),
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                      child: _text.text.trim().isEmpty
                          ? _RoundBtn(
                              key: const ValueKey('mic'),
                              icon: PhosphorIcons.microphone(PhosphorIconsStyle.fill),
                              label: 'Record a voice note',
                              onTap: _startRec,
                            )
                          : _RoundBtn(
                              key: const ValueKey('send'),
                              icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                              label: 'Send',
                              onTap: _sendText,
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SendError implements Exception {
  const _SendError(this.text);
  final String text;
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
        decoration: BoxDecoration(color: context.c.primary, shape: BoxShape.circle),
        child: Icon(icon, color: context.c.onPrimary, size: 22),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, this.online = false, this.onDark = false});
  final String name;
  final double size;
  final bool online, onDark;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.secondary, c.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: onDark ? Border.all(color: Colors.white24) : null,
            ),
            child: Text(initialsOf(name), style: context.ty.body.bold.col(Colors.white).copyWith(fontSize: size * .36)),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * .28,
                height: size * .28,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: onDark ? c.primary : c.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s3),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 4),
      decoration: BoxDecoration(color: context.c.surface.withValues(alpha: .92), borderRadius: BorderRadius.circular(8), boxShadow: context.shadow(1)),
      child: Text(text, style: context.ty.cap.bold.col(context.c.textMuted)),
    ),
  );
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: Space.s2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: c.textSubtle, shape: BoxShape.circle),
                  )
                  .animate(onPlay: (a) => a.repeat())
                  .moveY(begin: 0, end: -4, delay: (150 * i).ms, duration: 300.ms, curve: Curves.easeOut)
                  .then()
                  .moveY(begin: -4, end: 0, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

/// One message bubble. Mine (the student's) on the right in navy; the tutor's on the left in white.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.m, required this.mine, required this.first, required this.who, this.onRetry});
  final ChatMsg m;
  final bool mine, first;
  final String who;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (m.role == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Text(m.body, style: context.ty.cap.col(c.onAccentSoft), textAlign: TextAlign.center),
        ),
      );
    }
    final fg = mine ? c.onPrimary : c.text;
    final media = m.kind == 'image';
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      margin: EdgeInsets.only(top: first ? Space.s2 : 2),
      padding: media ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: mine ? c.primary : c.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!mine && first ? 4 : 18),
          topRight: Radius.circular(mine && first ? 4 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: context.shadow(1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine && first) Text(who, style: context.ty.cap.bold.col(c.secondary)),
          switch (m.kind) {
            'image' => _Photo(m: m),
            'voice' => _Voice(m: m, mine: mine),
            'file' => _FileCard(m: m, mine: mine),
            'link' => _CallCard(m: m, mine: mine),
            'ref' => _RefCard(m: m, mine: mine),
            _ => _LinkText(m.body, style: context.ty.body.col(fg).copyWith(height: 1.35), linkColor: mine ? c.accent : c.link),
          },
          Padding(
            padding: media ? const EdgeInsets.fromLTRB(6, 2, 6, 2) : const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chatTime(m.at), style: context.ty.cap.tnum.col(mine ? c.onPrimary.withValues(alpha: .7) : c.textSubtle).copyWith(fontSize: 11)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  if (m.failed)
                    Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), size: 14, color: c.accent)
                  else if (m.pending)
                    Icon(PhosphorIcons.clock(), size: 13, color: c.onPrimary.withValues(alpha: .7))
                  else
                    Icon(
                      m.readAt != null ? PhosphorIcons.checks(PhosphorIconsStyle.bold) : PhosphorIcons.check(PhosphorIconsStyle.bold),
                      size: 15,
                      color: m.readAt != null ? const Color(0xFF53BDEB) : c.onPrimary.withValues(alpha: .7),
                      semanticLabel: m.readAt != null ? 'Seen' : 'Sent',
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final row = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: onRetry == null ? bubble : GestureDetector(onTap: onRetry, child: bubble),
    );
    if (context.reduceMotion) return row;
    return row.animate().fadeIn(duration: 220.ms).slideY(begin: .15, end: 0, curve: Curves.easeOut).scaleXY(begin: .97, end: 1, duration: 220.ms);
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
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.m});
  final ChatMsg m;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width * .62;
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
                        child: R2Image(imageKey: m.attachment!, fit: BoxFit.contain, decodeWidth: 1600, semanticLabel: 'Photo'),
                      ),
                    ),
                  ),
                ),
              ),
        child: img,
      ),
    );
  }
}

/// Voice note: play / pause, a 26-bar wave that fills while it plays, the time.
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
  late final List<double> _bars = [for (var i = 0; i < 26; i++) .35 + .65 * (((i * 7 + widget.m.id) % 11) / 10)];

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
      setState(() => _vc = vc);
      await vc.play();
    } catch (_) {
      if (mounted) toast(context, 'Could not play this voice note.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = _vc?.value;
    final total = v != null && v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds / 1000 : (widget.m.meta['duration'] as num?)?.toDouble() ?? 0;
    final pos = v?.position.inMilliseconds ?? 0;
    final frac = total > 0 ? (pos / 1000 / total).clamp(0.0, 1.0) : 0.0;
    final on = widget.mine ? c.onPrimary : c.primary;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: v?.isPlaying == true ? 'Pause voice note' : 'Play voice note',
            child: InkResponse(
              onTap: widget.m.pending ? null : _toggle,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.mine ? Colors.white24 : c.primary, shape: BoxShape.circle),
                child: _loading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: widget.mine ? c.onPrimary : c.onPrimary))
                    : Icon(
                        v?.isPlaying == true ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
                        size: 18,
                        color: c.onPrimary,
                      ),
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
                                color: i / _bars.length <= frac ? on : on.withValues(alpha: .3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  fmtDur(v?.isPlaying == true || pos > 0 ? pos / 1000 : total),
                  style: context.ty.cap.tnum.col(widget.mine ? c.onPrimary.withValues(alpha: .8) : c.textMuted),
                ),
              ],
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
    final c = context.c;
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
        width: 230,
        padding: const EdgeInsets.all(Space.s2),
        decoration: BoxDecoration(color: mine ? Colors.white12 : c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(8)),
              child: Icon(PhosphorIcons.filePdf(PhosphorIconsStyle.fill), color: Colors.white),
            ),
            const Gap(Space.s2),
            Expanded(
              child: Text(
                '${m.meta['name'] ?? 'Document.pdf'}',
                style: context.ty.sm.bold.col(mine ? c.onPrimary : c.text),
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

class _CallCard extends StatelessWidget {
  const _CallCard({required this.m, required this.mine});
  final ChatMsg m;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final type = '${m.meta['type'] ?? 'video'}';
    final (icon, color) = switch (type) {
      'whatsapp' => (PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), const Color(0xFF25D366)),
      'meet' => (PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), const Color(0xFF1A73E8)),
      _ => (PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), const Color(0xFF7C3AED)),
    };
    final url = '${m.meta['url'] ?? ''}';
    return Container(
      width: 240,
      decoration: BoxDecoration(color: mine ? Colors.white12 : c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.s3),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white),
                ),
                const Gap(Space.s3),
                Expanded(child: Text(m.body.isEmpty ? 'Join the call' : m.body, style: context.ty.sm.bold.col(mine ? c.onPrimary : c.text), maxLines: 3)),
              ],
            ),
          ),
          Divider(height: 1, color: mine ? Colors.white24 : c.border),
          TextButton.icon(
            onPressed: url.startsWith('https://') ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
            icon: Icon(PhosphorIcons.phoneCall(PhosphorIconsStyle.fill), size: 18, color: mine ? c.accent : c.secondary),
            label: Text('Join now', style: context.ty.sm.bold.col(mine ? c.accent : c.secondary)),
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
    final c = context.c;
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
        width: 240,
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(color: mine ? Colors.white12 : c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
              child: Icon(pq ? PhosphorIcons.exam(PhosphorIconsStyle.fill) : PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill), color: c.onAccent),
            ),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['title'] ?? 'Study link'}', style: context.ty.sm.bold.col(mine ? c.onPrimary : c.text)),
                  if ('${r['snippet'] ?? ''}'.isNotEmpty)
                    Text(
                      '${r['snippet']}',
                      style: context.ty.cap.col(mine ? c.onPrimary.withValues(alpha: .8) : c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Gap(2),
                  Text(pq ? 'Past question · tap to open' : 'Lesson · tap to open', style: context.ty.cap.bold.col(mine ? c.accent : c.secondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
