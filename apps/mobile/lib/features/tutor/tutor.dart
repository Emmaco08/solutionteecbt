import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/engagement.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/item_pay.dart';
import '../premium/payments.dart';
import '../premium/paywall.dart';
import 'tutor_chat.dart';
import 'tutor_live.dart';

// Request a tutor, v3 (D-152, D-153): request → choose a plan (or a custom price) → pay (Paystack in the app, Google Play in
// the Play build, or the website as the admin chooses) → "Your tutor plan is on!" → "Finding your tutor" (live) → the
// tutor is revealed the moment they are assigned → chat with the tutor like WhatsApp. Every stage changes live.

final tutorProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'tutor:$uid', (s) => s.rpc('tutor_overview'), (j) => Map<String, dynamic>.from((j as Map?) ?? const {}));
});

const tutorLevels = [('jamb', 'JAMB'), ('waec', 'WAEC'), ('neco', 'NECO'), ('post_utme', 'Post-UTME'), ('other', 'Other')];
const tutorTimes = ['Mornings', 'Afternoons', 'Evenings', 'Weekends'];

/// Where the student is in the flow.
enum TutorStage { request, plans, waiting, chat, ended }

TutorStage tutorStage(Map<String, dynamic>? req, {bool hasTutor = false}) => switch ('${req?['status'] ?? 'closed'}') {
  'new' || 'quoted' => TutorStage.plans,
  'paid' => TutorStage.waiting,
  'matched' => hasTutor ? TutorStage.chat : TutorStage.waiting,
  'ended' => TutorStage.ended,
  _ => TutorStage.request,
};

/// Open request = choosing, paid or with a tutor (one at a time).
bool tutorOpen(Map<String, dynamic>? req) => req != null && const {'new', 'quoted', 'paid', 'matched'}.contains(req['status']);

/// "12 Dec 2026".
String tutorDate(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "just now", "12 minutes ago", "3 hours ago".
String tutorAgo(Object? iso, [DateTime? now]) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final m = (now ?? DateTime.now()).difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m minute${m == 1 ? '' : 's'} ago';
  final h = m ~/ 60;
  return '$h hour${h == 1 ? '' : 's'} ago';
}

/// WhatsApp link for a Nigerian number: 0801… → 234801…
Uri whatsappUri(String number) {
  var n = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '234${n.substring(1)}';
  return Uri.parse('https://wa.me/$n');
}

/// The tutor-assigned reveal shows once: until the student says something after the tutor was assigned, or closes it.
bool tutorShowReveal(Map<String, dynamic>? req, List<Map<String, dynamic>> msgs, Set<String> dismissed) {
  if (req == null || req['status'] != 'matched' || dismissed.contains('${req['id']}')) return false;
  final at = DateTime.tryParse('${req['assigned_at'] ?? ''}');
  if (at == null || DateTime.now().difference(at) > const Duration(days: 3)) return false;
  return !msgs.any((m) => m['role'] == 'student' && (DateTime.tryParse('${m['at']}')?.isAfter(at) ?? false));
}

/// Plan features: one per line of the admin's description ("•", "-" and "·" lists work too).
List<String> planFeatures(String desc) => [
  for (final l in desc.split(RegExp(r'\n|•|·|;')))
    if (l.replaceFirst(RegExp(r'^\s*[-*]\s*'), '').trim().isNotEmpty) l.replaceFirst(RegExp(r'^\s*[-*]\s*'), '').trim(),
];

/// Study card: the way in (shows the tutor's name and unread messages once matched).
class TutorCard extends ConsumerWidget {
  const TutorCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final d = ref.watch(tutorProvider).value ?? const {};
    final req = d['request'] == null ? null : Map<String, dynamic>.from(d['request'] as Map);
    final tutor = d['tutor'] as Map?;
    final unread = (d['unread'] as num?)?.toInt() ?? 0;
    final stage = tutorStage(req, hasTutor: tutor != null);
    final (title, caption) = switch (stage) {
      TutorStage.chat => (
        'My tutor: ${tutor?['name']}',
        unread > 0 ? '$unread new message${unread == 1 ? '' : 's'}' : 'Chat, send photos and voice notes, join calls.',
      ),
      TutorStage.waiting => ('My tutor', 'Payment received. Your tutor is coming within 24 hours.'),
      TutorStage.plans => ('Request a tutor', 'Choose a plan to get your tutor.'),
      TutorStage.ended => ('My tutor', 'Your plan has ended. Renew to keep learning.'),
      _ => ('Get a real tutor', 'A real teacher for the subjects you find hard.'),
    };
    return AppCard(
      onTap: () => context.push('/tutor'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), tone: Tone.green, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.ty.body.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                const Gap(2),
                Text(caption, style: context.ty.cap.col(unread > 0 ? c.success : c.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.success, borderRadius: BorderRadius.circular(12)),
              child: Text('$unread', style: context.ty.cap.bold.col(Colors.white)),
            )
          else
            Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
  }
}

class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});
  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

String? _uid() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null; // not set up (tests)
  }
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  static final _dismissed = <String>{}; // reveals closed in this app session
  bool _support = false; // chat with the SolutionTee team before a tutor is assigned
  String? _hello; // "Say hello": the chat opens with this draft
  LiveChannel? _live;
  ResumeWatcher? _resume;
  Timer? _poll;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    final uid = _uid();
    Engagement.visited(context, 'tutor');
    if (uid != null) {
      // Payment confirmed, tutor assigned, plan ended: the request row changes and this screen follows at once.
      _live = LiveChannel(
        'tutor-req:$uid',
        (ch) => ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tutor_requests',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (_) => _refreshSoon(),
        ),
        onUp: (_) {
          if (mounted) setState(() => _isLive = true);
          _refreshSoon();
        },
        onDown: () => mounted ? setState(() => _isLive = false) : null,
      )..open();
    }
    _resume = ResumeWatcher(() {
      _live?.restart();
      _refreshSoon();
    });
    // Safety net while waiting (website payments, a channel that is still joining): ask now and then.
    _poll = Timer.periodic(const Duration(seconds: 20), (t) {
      final req = ref.read(tutorProvider).value?['request'] as Map?;
      final waiting = const {'new', 'quoted', 'paid'}.contains(req?['status']);
      if (mounted && waiting && (!_isLive || t.tick % 3 == 0)) ref.invalidate(tutorProvider);
    });
  }

  Timer? _soon;
  void _refreshSoon() {
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 300), () => mounted ? ref.invalidate(tutorProvider) : null);
  }

  @override
  void dispose() {
    _live?.close();
    _resume?.dispose();
    _poll?.cancel();
    _soon?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(tutorProvider);
    await ref.read(tutorProvider.future).catchError((_) => const <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(tutorProvider);
    final d = v.value;
    final req = d?['request'] == null ? null : Map<String, dynamic>.from(d!['request'] as Map);
    final tutor = d?['tutor'] == null ? null : Map<String, dynamic>.from(d!['tutor'] as Map);
    final stage = tutorStage(req, hasTutor: tutor != null);
    final msgs = [for (final m in (d?['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];

    if (d != null && req != null && tutor != null && stage == TutorStage.chat && _hello == null && tutorShowReveal(req, msgs, _dismissed)) {
      return TutorMatchedView(
        data: d,
        onHello: () => setState(() => _hello = 'Hello ${'${tutor['name']}'.split(' ').first}! '),
        onClose: () => setState(() => _dismissed.add('${req['id']}')),
      );
    }
    if (d != null && req != null && (stage == TutorStage.chat || stage == TutorStage.ended || _support)) {
      return TutorChatView(
        key: ValueKey('chat-${req['id']}'),
        requestId: '${req['id']}',
        initial: msgs,
        tutor: stage == TutorStage.chat || stage == TutorStage.ended ? tutor : null,
        draft: _hello,
        readOnly: stage == TutorStage.ended ? 'Your tutor plan has ended. Renew it to keep chatting.' : null,
        footer: stage == TutorStage.ended ? _RenewBar(onTap: () => _openPlans(context, d)) : null,
        onBack: _support ? () => setState(() => _support = false) : null,
      );
    }
    return asyncView(
      v,
      onRetry: _refresh,
      loading: Scaffold(
        appBar: const TopBar(title: 'My tutor'),
        body: const ListSkeleton(),
      ),
      (d) => switch (stage) {
        TutorStage.request => const TutorRequestPage(),
        TutorStage.waiting => _WaitingPage(data: d, live: _isLive, onChat: () => setState(() => _support = true), onRefresh: _refresh),
        _ => _PlansPage(data: d, onChat: () => setState(() => _support = true), onRefresh: _refresh),
      },
    );
  }

  void _openPlans(BuildContext context, Map<String, dynamic> d) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => _PlansPage(data: d, onChat: () {}, onRefresh: _refresh, renew: true),
    ),
  );
}

class _RenewBar extends StatelessWidget {
  const _RenewBar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    color: context.c.accentSoft,
    padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s2, Space.s2),
    child: Row(
      children: [
        Expanded(child: Text('Keep learning with your tutor', style: context.ty.sm.bold.col(context.c.onAccentSoft))),
        Btn('Renew', sm: true, kind: BtnKind.accent, onPressed: onTap),
      ],
    ),
  );
}

// ---------------------------------------------------------------- shared bits

/// The bar at the bottom with the one main action.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.c.bg,
      border: Border(top: BorderSide(color: context.c.border)),
    ),
    padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
    child: SafeArea(top: false, child: child),
  );
}

/// Gold main button (navy text), 54 tall, as in the designs.
class _GoldCta extends StatelessWidget {
  const _GoldCta(this.label, {required this.onTap, this.icon, this.loading = false});
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: loading ? null : onTap,
      scale: .98,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(18)),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.navy900))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: context.ty.body.bold.col(Palette.navy900).copyWith(fontSize: 16)),
                  if (icon != null) ...[const Gap(Space.s2), Icon(icon, size: 18, color: Palette.navy900)],
                ],
              ),
      ),
    ),
  );
}

/// Small green "Live" label: shown while the live connection is up.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});
  final bool live;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
    );
    return Padding(
      padding: const EdgeInsets.only(right: Space.s3),
      child: AnimatedOpacity(
        // Shown only while the live connection is up (the page still checks every 20 s without it).
        opacity: live ? 1 : 0,
        duration: Motion.base,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            !context.reduceMotion ? dot.animate(onPlay: (a) => a.repeat(reverse: true)).fade(begin: 1, end: .35, duration: 900.ms) : dot,
            const Gap(6),
            Text('Live', style: context.ty.cap.bold.col(c.success)),
          ],
        ),
      ),
    );
  }
}

Widget _rise(BuildContext context, Widget w, int i) =>
    context.reduceMotion ? w : w.animate().fadeIn(delay: (60 * i).ms, duration: Motion.base).slideY(begin: .08, end: 0, curve: Curves.easeOut);

// ---------------------------------------------------------------- 1. Request

/// Exam, subjects (the student's combination first, up to 4), what they need and when they are free.
class TutorRequestPage extends ConsumerStatefulWidget {
  const TutorRequestPage({super.key});
  @override
  ConsumerState<TutorRequestPage> createState() => _TutorRequestPageState();
}

class _TutorRequestPageState extends ConsumerState<TutorRequestPage> {
  final _goals = TextEditingController();
  final _subjects = <int>[];
  final _times = <String>{};
  final _extra = <int>[]; // subjects added from "Another subject"
  String _level = 'jamb';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _goals.dispose();
    super.dispose();
  }

  void _addHint(String t) {
    final cur = _goals.text.trim();
    _goals.text = cur.isEmpty ? t : '$cur ${cur.endsWith('.') ? '' : '. '}$t'.replaceAll('  ', ' ');
    _goals.selection = TextSelection.collapsed(offset: _goals.text.length);
    setState(() {});
  }

  void _toggle(int id) => setState(() {
    if (_subjects.remove(id)) return;
    if (_subjects.length >= 4) {
      toast(context, 'Choose up to 4 subjects.', icon: PhosphorIcons.info(PhosphorIconsStyle.fill));
      return;
    }
    _subjects.add(id);
  });

  Future<void> _send() async {
    if (_goals.text.trim().length < 5) return setState(() => _error = 'Tell us a little about what you need (at least 5 letters).');
    setState(() => (_busy = true, _error = null));
    try {
      final r = Map<String, dynamic>.from(
        await Supabase.instance.client
                .rpc(
                  'tutor_request_create',
                  params: {
                    'p_subject': _subjects.isEmpty ? null : _subjects.first,
                    'p_subjects': _subjects.isEmpty ? null : _subjects,
                    'p_level': _level,
                    'p_goals': _goals.text.trim(),
                    'p_times': [
                      for (final t in tutorTimes)
                        if (_times.contains(t)) t,
                    ].join(', '),
                  },
                )
                .timeout(const Duration(seconds: 15))
            as Map,
      );
      if (!mounted) return;
      if (r['ok'] == true) {
        ref.invalidate(tutorProvider);
      } else {
        setState(
          () => _error = switch ('${r['error']}') {
            'open' => 'You already have an open request.',
            'too_many' => 'You have sent a few requests today. Please try again tomorrow.',
            _ => 'Tell us a little about what you need.',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach SolutionTee. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _more(List<Map<String, dynamic>> all) => showSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Another subject', style: ctx.ty.h2),
          const Gap(Space.s1),
          Text('Choose up to 4 subjects in all.', style: ctx.ty.sm.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final s in all)
                AppChip(
                  '${s['name']}',
                  on: _subjects.contains((s['id'] as num).toInt()),
                  onTap: () {
                    final id = (s['id'] as num).toInt();
                    _toggle(id);
                    if (_subjects.contains(id) && !_extra.contains(id)) _extra.add(id);
                    set(() {});
                  },
                ),
            ],
          ),
          const Gap(Space.s5),
          Btn('Done', block: true, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    final codes = [for (final s in (ref.watch(profileProvider).value?['jamb_subjects'] as List? ?? const [])) '$s'.toLowerCase()];
    final mine = [for (final code in codes) ...subjects.where((s) => '${s['code']}'.toLowerCase() == code || '${s['name']}'.toLowerCase() == code)];
    final shown = [
      ...mine,
      for (final id in _extra)
        if (!mine.any((m) => m['id'] == id)) ...subjects.where((s) => (s['id'] as num).toInt() == id),
    ];
    Widget label(String t, [String? hint]) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Text.rich(
        TextSpan(
          text: t,
          style: context.ty.sm.bold,
          children: [if (hint != null) TextSpan(text: '  ·  $hint', style: context.ty.cap.col(c.textSubtle))],
        ),
      ),
    );

    return Scaffold(
      appBar: const TopBar(title: 'Get a tutor'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s1, Space.s4, Space.s6),
        children: [
          _rise(context, const _Hero(), 0),
          const Gap(Space.s5),
          _rise(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('Exam'),
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  children: [for (final (k, l) in tutorLevels) AppChip(l, on: _level == k, onTap: () => setState(() => _level = k))],
                ),
              ],
            ),
            1,
          ),
          const Gap(Space.s5),
          _rise(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('Subject', mine.isEmpty ? 'up to 4' : 'from your JAMB combination'),
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  children: [
                    for (final s in shown)
                      AppChip('${s['name']}', on: _subjects.contains((s['id'] as num).toInt()), onTap: () => _toggle((s['id'] as num).toInt())),
                    AppChip(shown.isEmpty ? 'Choose subjects' : 'Another subject', on: false, icon: PhosphorIcons.plus(), onTap: () => _more(subjects)),
                  ],
                ),
              ],
            ),
            2,
          ),
          const Gap(Space.s5),
          _rise(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('What do you want help with?'),
                TextField(
                  controller: _goals,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.ty.body,
                  decoration: const InputDecoration(hintText: 'For example: I keep failing graphs and motion questions. I want 250+ in JAMB.', counterText: ''),
                ),
                const Gap(Space.s2),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (t, add) in const [
                      ('+ Weak topics', 'I need help with my weak topics.'),
                      ('+ Exam in 3 months', 'My exam is in 3 months.'),
                      ('+ Homework help', 'I want help with homework.'),
                    ])
                      _HintChip(t, onTap: () => _addHint(add)),
                  ],
                ),
              ],
            ),
            3,
          ),
          const Gap(Space.s5),
          _rise(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('When are you free?', 'optional'),
                Row(
                  children: [
                    for (final (i, t) in tutorTimes.indexed) ...[
                      if (i > 0) const Gap(Space.s2),
                      Expanded(
                        child: _TimeTile(t, on: _times.contains(t), onTap: () => setState(() => _times.contains(t) ? _times.remove(t) : _times.add(t))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            4,
          ),
          if (_error != null) ...[const Gap(Space.s4), ErrText(_error!)],
        ],
      ),
      bottomNavigationBar: _BottomBar(
        child: _GoldCta('See tutor plans', icon: PhosphorIcons.arrowRight(), loading: _busy, onTap: _send),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    Widget tag(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
      child: Text(t, style: context.ty.cap.bold.col(Colors.white)),
    );
    final icon = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(16)),
      child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 30, color: Palette.navy900),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.navy900,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.isDark ? context.c.border : Palette.navy900),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(color: Palette.blue600.withValues(alpha: .35), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 22,
            top: 22,
            child: context.reduceMotion
                ? icon
                : icon.animate(onPlay: (a) => a.repeat(reverse: true)).moveY(begin: 0, end: -4, duration: 1600.ms, curve: Curves.easeInOut),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1-ON-1 TUTORING', style: context.ty.cap.bold.col(Palette.gold400).copyWith(letterSpacing: 1)),
                const Gap(6),
                Padding(
                  padding: const EdgeInsets.only(right: 72),
                  child: Text('Learn with a real teacher', style: context.ty.h1.col(Colors.white)),
                ),
                const Gap(6),
                Padding(
                  padding: const EdgeInsets.only(right: 60),
                  child: Text('Chat, voice notes and live classes with a tutor who knows your exam.', style: context.ty.sm.col(Palette.navy100)),
                ),
                const Gap(Space.s4),
                Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [tag('Tutor in 24 h'), tag('Pay safely'), tag('Chat like WhatsApp')]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Pressable(
      onTap: onTap,
      scale: .95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: context.ty.cap.col(context.c.textMuted)),
      ),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile(this.text, {required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: on,
      child: Pressable(
        onTap: onTap,
        scale: .96,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.secondarySoft : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? c.secondary : c.border),
          ),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(text, style: (on ? context.ty.cap.bold.col(c.onSecondarySoft) : context.ty.cap.col(c.textMuted))),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 2. Plans

class _PlansPage extends ConsumerStatefulWidget {
  const _PlansPage({required this.data, required this.onChat, required this.onRefresh, this.renew = false});
  final Map<String, dynamic> data;
  final VoidCallback onChat;
  final Future<void> Function() onRefresh;
  final bool renew;
  @override
  ConsumerState<_PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends ConsumerState<_PlansPage> {
  String? _pick; // plan id, or the request id for the custom price
  bool _paying = false;

  void _say(String m, [IconData? i]) => toast(context, m, icon: i ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _pay({required String ref_, required String title, required int price, String? playId}) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      PayResult r;
      if (usesPaystackNow(ref)) {
        r = await payForItem(context, ref, itemRef: ref_, title: title, priceKobo: price);
      } else {
        final s = ref.read(paySettingsProvider);
        if (playId != null && playId.isNotEmpty && s.playGoogle) {
          r = await ref.read(paymentProvider(false)).buy({'play_product_id': playId});
        } else {
          // No Google Play product (custom prices, or the admin offers the website): pay on cbt.solutiontee.com/tutor,
          // which brings the student back here when it is paid (the screen then changes live).
          String? h;
          try {
            h = await ref.read(apiProvider).webHandoff().timeout(const Duration(seconds: 8));
          } catch (_) {}
          final ok = await launchUrl(
            Uri.https('cbt.solutiontee.com', '/tutor', {'h': ?h, 'from': 'app'}),
            mode: LaunchMode.externalApplication,
          ).catchError((_) => false);
          if (!ok && mounted) _say('Open cbt.solutiontee.com/tutor in your browser to pay.');
          return;
        }
      }
      if (!mounted) return;
      switch (r) {
        case PaySuccess():
          ref.invalidate(tutorProvider);
          if (widget.renew) Navigator.of(context).maybePop();
          context.push('/tutor/paid');
        case PayFailed(:final message):
          _say(message, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        case PayCancelled():
          _say('Payment cancelled. You were not charged.');
        case PayPending():
          _say('We are waiting for the payment to be confirmed. This page changes by itself.', PhosphorIcons.clock(PhosphorIconsStyle.fill));
          ref.invalidate(tutorProvider);
        default:
          break;
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _custom(Map<String, dynamic> req) => showSheet<void>(context, builder: (ctx) => _CustomAsk(req: req));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = ref.watch(tutorProvider).value ?? widget.data;
    final req = Map<String, dynamic>.from(d['request'] as Map? ?? const {});
    final plans = [for (final p in (d['plans'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    final customPrice = (req['custom_price_kobo'] as num?)?.toInt();
    final best = plans.length >= 3 ? 1 : (plans.isEmpty ? -1 : 0);
    final options = <({String id, String name, int price, String line, List<String> features, String? playId, bool popular, bool custom})>[
      if (customPrice != null)
        (
          id: '${req['id']}',
          name: 'Your custom plan',
          price: customPrice,
          line: '${req['custom_days'] ?? 30} days',
          features: planFeatures('${req['custom_note'] ?? ''}'),
          playId: null,
          popular: false,
          custom: true,
        ),
      for (final (i, p) in plans.indexed)
        (
          id: '${p['id']}',
          name: '${p['name']}',
          price: (p['price_kobo'] as num).toInt(),
          line: [
            if (p['sessions'] != null) '${p['sessions']} lessons',
            '${p['days']} days',
            if (p['sessions'] != null && (p['sessions'] as num) > 0) '${naira((p['price_kobo'] as num) / (p['sessions'] as num))} a lesson',
          ].join(' · '),
          features: planFeatures('${p['description'] ?? ''}'),
          playId: p['play_product_id'] as String?,
          popular: i == best && customPrice == null,
          custom: false,
        ),
    ];
    final pick = options.where((o) => o.id == _pick).firstOrNull ?? options.where((o) => o.custom || o.popular).firstOrNull ?? options.firstOrNull;
    final asked = req['custom_note'] != null && customPrice == null;
    final summary = [
      if ('${req['subjects'] ?? ''}'.isNotEmpty) '${req['subjects']}',
      tutorLevels.where((l) => l.$1 == req['level']).map((l) => l.$2).firstOrNull ?? '',
      if ('${req['times'] ?? ''}'.isNotEmpty) '${req['times']}'.toLowerCase(),
    ].where((x) => x.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: TopBar(
        title: widget.renew || req['status'] == 'ended' ? 'Renew your plan' : 'Choose your plan',
        actions: [
          if (!widget.renew)
            Padding(
              padding: const EdgeInsets.only(right: Space.s3),
              child: Center(child: Text('Step 2 of 3', style: context.ty.cap.col(c.textMuted))),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s6),
          children: [
            if (!widget.renew) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: 2 / 3, minHeight: 4, color: Palette.gold400, backgroundColor: c.surfaceSunken),
              ),
              const Gap(Space.s3),
            ],
            if (summary.isNotEmpty) Text(summary, style: context.ty.sm.col(c.textMuted)),
            const Gap(Space.s4),
            for (final (i, o) in options.indexed)
              _rise(
                context,
                Padding(
                  padding: EdgeInsets.only(bottom: Space.s3, top: o.popular || o.custom ? Space.s2 : 0),
                  child: _PlanTile(
                    name: o.name,
                    price: o.price,
                    line: o.line,
                    features: o.features,
                    badge: o.custom ? 'FOR YOU' : (o.popular ? 'MOST POPULAR' : null),
                    selected: pick?.id == o.id,
                    onTap: () => setState(() => _pick = o.id),
                  ),
                ),
                i,
              ),
            if (req['id'] != null)
              _rise(context, _CustomRow(asked: asked, note: '${req['custom_note'] ?? ''}', onTap: asked ? null : () => _custom(req)), options.length),
            const Gap(Space.s4),
            if (!widget.renew)
              Center(
                child: TextButton.icon(
                  onPressed: widget.onChat,
                  icon: Icon(PhosphorIcons.chatsCircle(), size: 18),
                  label: const Text('Questions? Chat with SolutionTee'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: pick == null
          ? null
          : _BottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GoldCta(
                    'Pay ${naira(pick.price)}',
                    loading: _paying,
                    onTap: () =>
                        _pay(ref_: pick.id, title: pick.custom ? 'Custom tutor plan' : 'Tutor plan: ${pick.name}', price: pick.price, playId: pick.playId),
                  ),
                  const Gap(Space.s2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 13, color: c.textSubtle),
                      const Gap(6),
                      Flexible(
                        child: Text(
                          usesPaystack(ref) ? 'Card, transfer, USSD or bank app (Paystack)' : 'Google Play, or our website for custom plans',
                          style: context.ty.cap.col(c.textSubtle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.name,
    required this.price,
    required this.line,
    required this.features,
    required this.selected,
    required this.onTap,
    this.badge,
  });
  final String name, line;
  final int price;
  final List<String> features;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = context.isDark;
    // Selected: navy card with a gold border (light: navy too, so the gold stays readable).
    final bg = selected ? Palette.navy900 : c.surface;
    final fg = selected ? Colors.white : c.text;
    final sub = selected ? Palette.navy100 : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, ${naira(price)}',
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.out,
              width: double.infinity,
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? Palette.gold400 : (dark ? c.border : c.border), width: selected ? 2 : 1),
                boxShadow: selected ? context.shadow(2) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: Motion.fast,
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? Palette.gold400 : Colors.transparent,
                          border: selected ? null : Border.all(color: c.borderStrong, width: 2),
                        ),
                        child: selected ? Icon(PhosphorIcons.check(), size: 13, color: Palette.navy900) : null,
                      ),
                      const Gap(Space.s3),
                      Expanded(child: Text(name, style: context.ty.body.bold.col(fg))),
                      Text(naira(price), style: context.ty.h2.tnum.col(fg)),
                    ],
                  ),
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 34, top: 2),
                      child: Text(line, style: context.ty.cap.col(sub)),
                    ),
                  AnimatedSize(
                    duration: Motion.base,
                    curve: Motion.out,
                    alignment: Alignment.topCenter,
                    child: selected && features.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(left: 34, top: Space.s3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final f in features.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(PhosphorIcons.check(), size: 16, color: Palette.green300),
                                        const Gap(Space.s2),
                                        Expanded(child: Text(f, style: context.ty.sm.col(Colors.white))),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: -11,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge!, style: context.ty.cap.bold.col(Palette.navy900).copyWith(fontSize: 11, letterSpacing: .6)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomRow extends StatelessWidget {
  const _CustomRow({required this.asked, required this.note, required this.onTap});
  final bool asked;
  final String note;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: onTap != null,
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: _DashedBorder(color: c.borderStrong, radius: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 20, color: context.isDark ? Palette.gold400 : Palette.gold700),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asked ? 'Custom plan: price coming' : 'Custom plan', style: context.ty.body.bold),
                      Text(
                        asked ? 'We got: "$note". We will send a price soon, usually within a day.' : 'Weekend class, group, more lessons: we send a price',
                        style: context.ty.cap.col(c.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTap != null) Icon(PhosphorIcons.caretRight(), size: 18, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _CustomAsk extends ConsumerStatefulWidget {
  const _CustomAsk({required this.req});
  final Map<String, dynamic> req;
  @override
  ConsumerState<_CustomAsk> createState() => _CustomAskState();
}

class _CustomAskState extends ConsumerState<_CustomAsk> {
  final _t = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_t.text.trim().length < 5) return setState(() => _err = 'Tell us a little more about what you need.');
    setState(() => (_busy = true, _err = null));
    try {
      final r = await Supabase.instance.client.rpc('tutor_custom_request', params: {'p_request': '${widget.req['id']}', 'p_note': _t.text.trim()});
      if (!mounted) return;
      if ((r as Map?)?['ok'] == true) {
        ref.invalidate(tutorProvider);
        Navigator.pop(context);
        toast(context, 'Sent. We will send you a price, usually within a day.');
      } else {
        setState(() => _err = 'Could not send. Try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _err = 'Could not reach SolutionTee. Check your internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Ask for a custom plan', style: context.ty.h2),
      const Gap(Space.s1),
      Text('More lessons, weekend classes, a group with friends? Tell us and we send you a price.', style: context.ty.sm.col(context.c.textMuted)),
      const Gap(Space.s4),
      TextField(
        controller: _t,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        style: context.ty.body,
        decoration: const InputDecoration(hintText: 'I need weekend classes for 2 months', counterText: ''),
      ),
      if (_err != null) ...[const Gap(Space.s2), ErrText(_err!)],
      const Gap(Space.s4),
      Btn('Ask for a price', block: true, loading: _busy, onPressed: _busy ? null : _send),
    ],
  );
}

// ---------------------------------------------------------------- 3. Paid

/// "Your tutor plan is on!" after a tutor payment (in the app, or back from the website). Never "Premium".
class TutorPaidScreen extends ConsumerStatefulWidget {
  const TutorPaidScreen({super.key});
  @override
  ConsumerState<TutorPaidScreen> createState() => _TutorPaidScreenState();
}

class _TutorPaidScreenState extends ConsumerState<TutorPaidScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(tutorProvider));
  }

  void _continue() => context.canPop() ? context.pop() : context.go('/tutor');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final d = ref.watch(tutorProvider).value ?? const {};
    final sub = d['subscription'] == null ? null : Map<String, dynamic>.from(d['subscription'] as Map);
    final req = d['request'] == null ? null : Map<String, dynamic>.from(d['request'] as Map);
    final hasTutor = d['tutor'] != null && req?['status'] == 'matched';
    final subjects = '${req?['subjects'] ?? ''}';
    final amount = (sub?['amount_kobo'] as num?)?.toInt();
    final reference = '${sub?['reference'] ?? ''}';
    Widget row(String k, String v, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 13),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Text(k, style: context.ty.sm.col(c.textMuted)),
          const Gap(Space.s3),
          Expanded(
            child: Text(v, style: context.ty.sm.bold, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s5, vertical: Space.s4),
                  child: Column(
                    children: [
                      _SuccessBurst(reduce: rm),
                      const Gap(Space.s4),
                      _rise(
                        context,
                        Text(amount != null ? 'Payment received · ${naira(amount)}' : 'Payment received', style: context.ty.sm.bold.col(c.success)),
                        2,
                      ),
                      const Gap(6),
                      _rise(
                        context,
                        Text(
                          hasTutor ? 'Your plan is renewed!' : 'Your tutor plan is on!',
                          style: context.ty.display.copyWith(fontSize: 28),
                          textAlign: TextAlign.center,
                        ),
                        3,
                      ),
                      const Gap(Space.s2),
                      _rise(
                        context,
                        Text(
                          hasTutor
                              ? 'Keep learning with ${(d['tutor'] as Map)['name']}.'
                              : 'We are matching you with a tutor${subjects.isEmpty ? '' : ' for $subjects'}. This usually takes less than 24 hours.',
                          style: context.ty.body.col(c.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        4,
                      ),
                      const Gap(Space.s5),
                      _rise(
                        context,
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.border),
                          ),
                          child: sub == null
                              ? const Padding(padding: EdgeInsets.all(Space.s4), child: LinearProgressIndicator())
                              : Column(
                                  children: [
                                    row('Plan', [sub['plan'], if (sub['sessions'] != null) '${sub['sessions']} lessons'].join(' · ')),
                                    row('Runs until', tutorDate(sub['ends_at']), last: reference.isEmpty),
                                    if (reference.isNotEmpty)
                                      row(
                                        'Receipt',
                                        reference.length > 12 ? '${reference.substring(0, 7)}…${reference.substring(reference.length - 3)}' : reference,
                                        last: true,
                                      ),
                                  ],
                                ),
                        ),
                        5,
                      ),
                      if (!hasTutor) ...[
                        const Gap(Space.s4),
                        _rise(
                          context,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.bellRinging(PhosphorIconsStyle.fill), size: 20, color: context.isDark ? Palette.gold400 : c.onSecondarySoft),
                                const Gap(10),
                                Expanded(child: Text('We will notify you the moment your tutor is assigned.', style: context.ty.sm.col(c.onSecondarySoft))),
                              ],
                            ),
                          ),
                          6,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s4),
              child: _GoldCta(hasTutor ? 'Back to the chat' : 'Continue', onTap: _continue),
            ),
          ],
        ),
      ),
    );
  }
}

/// A green check that pops in, rings that settle and a few confetti pieces that fly out.
class _SuccessBurst extends StatelessWidget {
  const _SuccessBurst({required this.reduce});
  final bool reduce;
  @override
  Widget build(BuildContext context) {
    final green = context.c.success;
    Widget ring(double inset, double a) => Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: green.withValues(alpha: a),
          ),
        ),
      ),
    );
    final check = Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: green,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: green.withValues(alpha: .35), blurRadius: 24)],
      ),
      child: Icon(PhosphorIcons.check(), size: 42, color: Colors.white),
    );
    const bits = [
      (Offset(-62, -40), Palette.gold400, 20.0, false),
      (Offset(58, -54), Palette.blue400, -30.0, true),
      (Offset(66, 28), Palette.gold400, 0.0, false),
      (Offset(-58, 44), Palette.green300, 40.0, true),
      (Offset(10, -72), Palette.green300, 10.0, false),
      (Offset(-20, 70), Palette.blue400, 60.0, true),
    ];
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (reduce) ...[
            ring(0, .08),
            ring(18, .14),
          ] else ...[
            ring(0, .08).animate().scaleXY(begin: .4, end: 1, duration: 700.ms, curve: Curves.easeOutBack),
            ring(18, .14).animate().scaleXY(begin: .4, end: 1, delay: 80.ms, duration: 600.ms, curve: Curves.easeOutBack),
          ],
          reduce ? check : check.animate().scaleXY(begin: .2, end: 1, duration: 520.ms, curve: Curves.elasticOut).fadeIn(duration: 160.ms),
          for (final (o, col, rot, long) in bits)
            Transform.rotate(
                  angle: rot * 3.14159 / 180,
                  child: Container(
                    width: long ? 6 : 9,
                    height: long ? 13 : 9,
                    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(long ? 2 : 5)),
                  ),
                )
                .animate(target: reduce ? 1 : null)
                .move(begin: Offset.zero, end: o, delay: 250.ms, duration: 650.ms, curve: Curves.easeOutCubic)
                .fadeIn(delay: 250.ms, duration: 150.ms),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 4. Waiting

/// Paid: "Finding your tutor" with a live step list. It turns into the tutor reveal by itself.
class _WaitingPage extends StatelessWidget {
  const _WaitingPage({required this.data, required this.live, required this.onChat, required this.onRefresh});
  final Map<String, dynamic> data;
  final bool live;
  final VoidCallback onChat;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sub = data['subscription'] as Map?;
    final req = data['request'] as Map? ?? const {};
    final subjects = '${req['subjects'] ?? ''}';
    return Scaffold(
      appBar: TopBar(
        title: 'My tutor',
        actions: [_LiveDot(live: live)],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
          children: [
            const _Radar(),
            const Gap(Space.s4),
            Text('Finding your tutor', style: context.ty.display.copyWith(fontSize: 26), textAlign: TextAlign.center),
            const Gap(6),
            Text(
              'Usually within 24 hours. This page changes by itself the moment a tutor is assigned.',
              style: context.ty.body.col(c.textMuted),
              textAlign: TextAlign.center,
            ),
            const Gap(Space.s5),
            Container(
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  _Step(
                    title: 'Payment received',
                    text: sub != null ? '${sub['plan']} plan until ${tutorDate(sub['ends_at'])}' : 'Thank you!',
                    state: _StepState.done,
                    line: true,
                  ),
                  _Step(
                    title: subjects.isEmpty ? 'Matching you with a tutor' : 'Matching a $subjects tutor',
                    text: req['paid_at'] != null ? 'Started ${tutorAgo(req['paid_at'])}' : 'We pick a tutor for your subjects and goals.',
                    state: _StepState.now,
                    line: true,
                  ),
                  const _Step(title: 'Say hello to your tutor', text: 'Chat, calls, voice notes', state: _StepState.later),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        child: Btn('Questions? Chat with SolutionTee', kind: BtnKind.outline, block: true, leading: PhosphorIcons.chatsCircle(), onPressed: onChat),
      ),
    );
  }
}

enum _StepState { done, now, later }

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.text, required this.state, this.line = false});
  final String title, text;
  final _StepState state;
  final bool line;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dot = switch (state) {
      _StepState.done => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
        child: Icon(PhosphorIcons.check(), size: 15, color: Colors.white),
      ),
      _StepState.now => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.blue600,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Palette.blue600.withValues(alpha: .3), spreadRadius: 5)],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
      _StepState.later => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surfaceSunken, shape: BoxShape.circle),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c.textSubtle, shape: BoxShape.circle),
        ),
      ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              state == _StepState.now && !context.reduceMotion
                  ? dot.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: 1, end: 1.08, duration: 900.ms, curve: Curves.easeInOut)
                  : dot,
              if (line)
                Expanded(
                  child: Container(width: 2, constraints: const BoxConstraints(minHeight: 22), color: state == _StepState.done ? c.success : c.border),
                ),
            ],
          ),
          const Gap(Space.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: line ? Space.s3 : 0, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.ty.body.bold.col(state == _StepState.later ? c.textMuted : c.text)),
                  Text(text, style: context.ty.cap.col(state == _StepState.later ? c.textSubtle : c.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rings that pulse out from the centre while we look for a tutor, with subject icons drifting around them.
class _Radar extends StatelessWidget {
  const _Radar();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget ring(double inset, double a, int delay) {
      final w = Positioned.fill(
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Palette.blue400.withValues(alpha: a), width: 1.5),
            ),
          ),
        ),
      );
      return rm
          ? w
          : w
                .animate(onPlay: (x) => x.repeat())
                .scaleXY(begin: .85, end: 1.05, delay: delay.ms, duration: 2400.ms, curve: Curves.easeOut)
                .fade(begin: 1, end: .2, duration: 2400.ms);
    }

    Widget orb(Alignment a, IconData icon, double size, int i) {
      final w = Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: i == 1 ? Palette.blue600 : c.surfaceSunken,
            shape: BoxShape.circle,
            border: Border.all(color: c.bg, width: 2),
          ),
          child: Icon(icon, size: size * .45, color: i == 1 ? Colors.white : c.textMuted),
        ),
      );
      return rm
          ? w
          : w.animate(onPlay: (x) => x.repeat(reverse: true)).moveY(begin: 0, end: i.isEven ? -6 : 6, duration: (1800 + 300 * i).ms, curve: Curves.easeInOut);
    }

    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          children: [
            ring(0, .2, 0),
            ring(30, .3, 300),
            ring(60, .45, 600),
            orb(const Alignment(-.82, -.5), PhosphorIcons.mathOperations(PhosphorIconsStyle.fill), 40, 0),
            orb(const Alignment(.9, -.15), PhosphorIcons.atom(PhosphorIconsStyle.fill), 44, 1),
            orb(const Alignment(-.38, .95), PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill), 36, 2),
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.navy900,
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.gold400, width: 2),
                ),
                child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 44, color: Palette.gold400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 5. Tutor assigned

/// The tutor reveal: shown live the moment a tutor is assigned, until the student says hello.
class TutorMatchedView extends StatelessWidget {
  const TutorMatchedView({super.key, required this.data, required this.onHello, required this.onClose});
  final Map<String, dynamic> data;
  final VoidCallback onHello, onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final t = Map<String, dynamic>.from(data['tutor'] as Map);
    final sub = data['subscription'] as Map?;
    final name = '${t['name']}';
    final chips = [
      if (t['years'] != null) '${t['years']} years teaching',
      if ('${t['qualification'] ?? ''}'.isNotEmpty) '${t['qualification']}',
      if ((t['students'] as num? ?? 0) > 1) '${t['students']} students',
    ];
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Palette.gold400.withValues(alpha: .18), spreadRadius: 8),
              BoxShadow(color: Palette.gold400.withValues(alpha: .07), spreadRadius: 18),
            ],
          ),
          child: TutorAvatar(name: name, photo: t['photo_path'] as String?, size: 132),
        ),
        if (t['online'] == true)
          Positioned(
            right: 6,
            bottom: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Palette.green500,
                shape: BoxShape.circle,
                border: Border.all(color: c.bg, width: 4),
              ),
            ),
          ),
      ],
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: -60,
            top: -80,
            right: -60,
            height: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Palette.blue600.withValues(alpha: context.isDark ? .45 : .18),
                    Palette.blue600.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          if (!rm) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: Icon(PhosphorIcons.x(), color: c.textMuted),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                    child: Column(
                      children: [
                        _rise(
                          context,
                          Text(
                            'TUTOR ASSIGNED',
                            style: context.ty.cap.bold.col(context.isDark ? Palette.gold400 : Palette.gold700).copyWith(letterSpacing: 1.2),
                          ),
                          0,
                        ),
                        const Gap(Space.s5),
                        rm ? avatar : avatar.animate().scaleXY(begin: .3, end: 1, duration: 700.ms, curve: Curves.elasticOut).fadeIn(duration: 200.ms),
                        const Gap(Space.s5),
                        _rise(context, Text('Meet $name', style: context.ty.display.copyWith(fontSize: 26), textAlign: TextAlign.center), 3),
                        const Gap(4),
                        _rise(
                          context,
                          Text(
                            [if ('${t['subjects'] ?? ''}'.isNotEmpty) '${t['subjects']}', if (t['online'] == true) 'online now'].join(' · '),
                            style: context.ty.body.col(c.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          4,
                        ),
                        if (chips.isNotEmpty) ...[
                          const Gap(Space.s3),
                          _rise(
                            context,
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: Space.s2,
                              runSpacing: Space.s2,
                              children: [
                                for (final ch in chips)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
                                    child: Text(ch, style: context.ty.cap.bold),
                                  ),
                              ],
                            ),
                            5,
                          ),
                        ],
                        if ('${t['bio'] ?? ''}'.isNotEmpty) ...[
                          const Gap(Space.s5),
                          _rise(
                            context,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(Space.s4),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: c.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('About your tutor', style: context.ty.cap.bold.col(c.textMuted)),
                                  const Gap(6),
                                  Text('${t['bio']}', style: context.ty.body),
                                ],
                              ),
                            ),
                            6,
                          ),
                        ],
                        if (sub != null) ...[
                          const Gap(Space.s3),
                          _rise(
                            context,
                            Row(
                              children: [
                                if (sub['sessions'] != null) ...[
                                  Expanded(
                                    child: _Stat(label: 'Lessons', value: '${sub['sessions']} in your plan'),
                                  ),
                                  const Gap(10),
                                ],
                                Expanded(
                                  child: _Stat(label: 'Plan ends', value: tutorDate(sub['ends_at'])),
                                ),
                              ],
                            ),
                            7,
                          ),
                        ],
                        const Gap(Space.s5),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s3),
                  child: Column(
                    children: [
                      _GoldCta('Say hello', icon: PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill), onTap: onHello),
                      const Gap(Space.s2),
                      Text(
                        'Your chats, calls and voice notes with your tutor are all in here.',
                        style: context.ty.cap.col(c.textSubtle),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.s3),
    decoration: BoxDecoration(
      color: context.c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.c.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.ty.cap.col(context.c.textMuted)),
        Text(value, style: context.ty.body.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

/// A short burst of falling confetti (skipped with reduce motion).
class _Confetti extends StatelessWidget {
  const _Confetti();
  @override
  Widget build(BuildContext context) {
    const pieces = [
      (.15, Palette.gold400, 25.0, 0),
      (.78, Palette.blue400, -35.0, 120),
      (.84, Palette.gold400, 0.0, 240),
      (.10, Palette.green300, 40.0, 60),
      (.62, Palette.green300, 10.0, 180),
      (.40, Palette.gold300, -15.0, 300),
      (.92, Palette.blue300, 60.0, 90),
      (.28, Palette.blue400, -50.0, 210),
    ];
    return LayoutBuilder(
      builder: (_, box) => Stack(
        children: [
          for (final (x, col, rot, delay) in pieces)
            Positioned(
              left: box.maxWidth * x,
              top: 40,
              child:
                  Transform.rotate(
                        angle: rot * 3.14159 / 180,
                        child: Container(
                          width: rot.abs() > 20 ? 7 : 10,
                          height: rot.abs() > 20 ? 14 : 10,
                          decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(rot.abs() > 20 ? 2 : 5)),
                        ),
                      )
                      .animate(delay: delay.ms)
                      .moveY(begin: -60, end: box.maxHeight * .5, duration: 2200.ms, curve: Curves.easeIn)
                      .rotate(begin: 0, end: rot > 0 ? 1.5 : -1.5, duration: 2200.ms)
                      .fadeOut(delay: 1500.ms, duration: 700.ms),
            ),
        ],
      ),
    );
  }
}
