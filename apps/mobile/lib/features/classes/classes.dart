import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../../widgets/states.dart';
import '../premium/item_pay.dart';
import '../premium/payments.dart';
import '../premium/paywall.dart';
import 'classes_ui.dart';

// Online classes (C13, D-147). The list never carries a class link: the server hands it out (class_join) only to a
// student who may come in, from 15 minutes before the start until the end.

final classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'classes:$uid', (s) => s.rpc('classes_list'), rows);
});

/// Classes students buy once and attend every session of (classes v2, D-163).
final programsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'programs:$uid', (s) => s.rpc('programs_list'), rows);
});

/// One programme with its sessions.
final programProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final j = await Supabase.instance.client.rpc('program_detail', params: {'p_program': id}).timeout(const Duration(seconds: 15));
  return j is Map ? Map<String, dynamic>.from(j) : null;
});

DateTime? classStart(Map<String, dynamic> c) => DateTime.tryParse('${c['starts_at']}')?.toLocal();
DateTime? classEnd(Map<String, dynamic> c) => classStart(c)?.add(Duration(minutes: (c['minutes'] as num?)?.toInt() ?? 60));

enum ClassPhase { upcoming, live, ended, cancelled }

/// Upcoming → live (from 15 minutes before the start) → ended.
ClassPhase classPhase(Map<String, dynamic> c, DateTime now) {
  if (c['status'] == 'cancelled') return ClassPhase.cancelled;
  final s = classStart(c), e = classEnd(c);
  if (s == null || e == null) return ClassPhase.upcoming;
  if (now.isAfter(e)) return ClassPhase.ended;
  if (now.isAfter(s.subtract(const Duration(minutes: 15)))) return ClassPhase.live;
  return ClassPhase.upcoming;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Thu 12 Nov · 6:00 pm".
String classWhen(Map<String, dynamic> c) {
  final s = classStart(c);
  if (s == null) return '';
  final h = s.hour % 12 == 0 ? 12 : s.hour % 12;
  return '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]} · $h:${s.minute.toString().padLeft(2, '0')} ${s.hour < 12 ? 'am' : 'pm'}';
}

/// "in 2 days", "in 3 h", "in 25 min", "now".
String classIn(Map<String, dynamic> c, DateTime now) {
  final s = classStart(c);
  if (s == null) return '';
  final d = s.difference(now);
  if (d.isNegative) return 'now';
  if (d.inDays >= 1) return 'in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
  if (d.inHours >= 1) return 'in ${d.inHours} h';
  return 'in ${d.inMinutes.clamp(1, 59)} min';
}

String accessLabel(Map<String, dynamic> c) => switch ('${c['access']}') {
  'premium' => 'Premium',
  'paid' => naira((c['price_kobo'] as num?)?.toInt() ?? 0),
  _ => 'Free',
};

/// The next class (registered first, else any upcoming one), for Home and Study.
Map<String, dynamic>? nextClass(List<Map<String, dynamic>> list, DateTime now) {
  final open = [
    for (final c in list)
      if (classPhase(c, now) == ClassPhase.upcoming || classPhase(c, now) == ClassPhase.live) c,
  ];
  return open.where((c) => c['registered'] == true).firstOrNull ?? open.firstOrNull;
}

/// Home / Study card: the next class, with a live countdown (or LIVE and Join when it is on).
class NextClassCard extends ConsumerWidget {
  const NextClassCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(classesProvider).value ?? const <Map<String, dynamic>>[];
    final now = DateTime.now();
    final x = nextClass(list, now);
    if (x == null) return const SizedBox.shrink();
    final live = classPhase(x, now) == ClassPhase.live;
    final start = classStart(x)!, end = classEnd(x)!;
    final rm = context.reduceMotion;
    final card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/classes/${x['id']}'),
        child: Ink(
          padding: const EdgeInsets.all(Space.s4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (live)
                      const LivePulse(text: 'LIVE CLASS', small: true)
                    else
                      Text('NEXT LIVE CLASS', style: context.ty.cap.bold.copyWith(letterSpacing: 1).col(const Color(0xFFB9C7DE))),
                    const SizedBox(height: 6),
                    if ('${x['program_title'] ?? ''}'.isNotEmpty)
                      Text('${x['program_title']}', style: context.ty.cap.bold.col(Palette.gold300), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${x['title']}', style: context.ty.body.bold.col(Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${classWhen(x)} · ${x['teacher']}', style: context.ty.cap.col(const Color(0xFFB9C7DE)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (live) ...[const SizedBox(height: 10), ClassProgress(start: start, end: end, dark: true)],
                  ],
                ),
              ),
              const Gap(Space.s3),
              if (live)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text('Join', style: context.ty.label.bold.col(Palette.navy900)),
                )
              else
                ClassCountdown(to: start, dark: true, label: false),
            ],
          ),
        ),
      ),
    );
    return rm ? card : card.animate().fadeIn(duration: Motion.base).slideY(begin: .05, end: 0, curve: Curves.easeOutCubic);
  }
}

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rm = context.reduceMotion;
    return Scaffold(
      appBar: const TopBar(title: 'Live classes'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesProvider);
          ref.invalidate(programsProvider);
          await ref.read(classesProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
        },
        child: asyncView(ref.watch(classesProvider), (list) {
          final now = DateTime.now();
          final live = list.where((x) => classPhase(x, now) == ClassPhase.live).toList();
          final soon = list.where((x) => classPhase(x, now) == ClassPhase.upcoming).toList();
          final past = list.where((x) => classPhase(x, now) == ClassPhase.ended).toList().reversed.toList();
          if (live.isEmpty && soon.isEmpty && past.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                const _ProgramsSection(),
                StateBlock(
                  icon: PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
                  tone: Tone.blue,
                  title: 'No sessions scheduled yet',
                  text: 'Live sessions with our teachers show here. We will tell you when the next one is posted.',
                ),
              ],
            );
          }
          var i = 0;
          Widget group(String title, List<Map<String, dynamic>> xs) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectTitle(title),
              for (final x in xs) ...[
                Builder(
                  builder: (_) {
                    final card = _ClassTile(c: x, now: now);
                    final d = (40 * (i++).clamp(0, 8)).ms;
                    return rm ? card : card.animate().fadeIn(delay: d, duration: Motion.base).slideY(begin: .06, end: 0);
                  },
                ),
                const Gap(Space.s3),
              ],
              const Gap(Space.s3),
            ],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            children: [
              const _ProgramsSection(),
              if (live.isNotEmpty) group('Live now', live),
              if (soon.isNotEmpty) group('Coming up', soon),
              if (past.isNotEmpty) group('Past classes', past),
            ],
          );
        }, onRetry: () => ref.invalidate(classesProvider)),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.c, required this.now});
  final Map<String, dynamic> c;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final phase = classPhase(c, now);
    return AppCard(
      onTap: () => context.push('/classes/${c['id']}'),
      child: Row(
        children: [
          _DateBox(c: c, live: phase == ClassPhase.live),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ('${c['program_title'] ?? ''}'.isNotEmpty)
                  Text('${c['program_title']}', style: context.ty.cap.bold.col(col.onSecondarySoft), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${c['title']}', style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Gap(2),
                Text('${c['teacher']} · ${c['minutes']} min', style: context.ty.cap.col(col.textMuted)),
                const Gap(Space.s1),
                Wrap(
                  spacing: Space.s1,
                  runSpacing: Space.s1,
                  children: [
                    if (c['program_id'] == null)
                      Pill(accessLabel(c), kind: c['access'] == 'free' ? BadgeKind.success : (c['access'] == 'premium' ? BadgeKind.gold : BadgeKind.soft))
                    else if (c['allowed'] == true)
                      Pill('You are in', kind: BadgeKind.success, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
                    if (c['registered'] == true) Pill('Registered', kind: BadgeKind.success, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
                    if (phase == ClassPhase.ended && c['has_recording'] == true) Pill('Recording', icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill)),
                    if (phase == ClassPhase.cancelled) const Pill('Cancelled', kind: BadgeKind.error),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.c, required this.live});
  final Map<String, dynamic> c;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final s = classStart(c);
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      decoration: BoxDecoration(color: live ? const Color(0xFFE5484D) : col.secondarySoft, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        children: [
          Text(live ? 'LIVE' : (s == null ? '' : _months[s.month - 1].toUpperCase()), style: context.ty.over.col(live ? Colors.white : col.onSecondarySoft)),
          Text(s == null ? '' : '${s.day}', style: context.ty.h2.tnum.col(live ? Colors.white : col.onSecondarySoft)),
        ],
      ),
    );
  }
}

/// One class: what it covers, when, and the one action that fits (register, pay, join, watch the recording).
class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  bool _busy = false;

  Future<Map<String, dynamic>> _rpc(String fn) async =>
      Map<String, dynamic>.from(await Supabase.instance.client.rpc(fn, params: {'p_class': widget.id}).timeout(const Duration(seconds: 15)) as Map);

  void _say(String m, [IconData? icon]) => toast(context, m, icon: icon ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) _say('Could not reach SolutionTee. Check your internet and try again.', PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register(Map<String, dynamic> c) => _run(() async {
    final r = await _rpc('class_register');
    if (!mounted) return;
    if (r['ok'] == true) {
      ref.invalidate(classesProvider);
      return _say('You are registered. We will remind you before it starts.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    }
    switch ('${r['error']}') {
      case 'premium':
        await showPaywall(context, reason: 'classes');
      case 'pay':
        await _pay(c);
      case 'full':
        _say('This class is full.');
      case 'ended':
        _say('This class has ended.');
      default:
        _say('You cannot register for this class.');
    }
  });

  Future<void> _pay(Map<String, dynamic> c) async {
    if (!usesPaystackNow(ref)) {
      await launchUrl(Uri.parse('https://cbt.solutiontee.com/classes'), mode: LaunchMode.externalApplication);
      return;
    }
    final r = await payForItem(context, ref, itemRef: widget.id, title: '${c['title']}', priceKobo: (c['price_kobo'] as num?)?.toInt() ?? 0);
    if (!mounted) return;
    switch (r) {
      case PaySuccess():
        ref.invalidate(classesProvider);
        _say('You are in! We will remind you before it starts.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      case PayFailed(:final message):
        _say(message, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
      case PayCancelled():
        _say('Payment cancelled. You were not charged.');
      case PayPending():
        _say('We are waiting for Paystack. Your seat is saved as soon as the payment is confirmed.', PhosphorIcons.clock(PhosphorIconsStyle.fill));
      default:
        break;
    }
  }

  Future<void> _open(String fn) => _run(() async {
    final r = await _rpc(fn);
    if (!mounted) return;
    if (r['ok'] == true && '${r['url']}'.startsWith('https://')) {
      ref.invalidate(classesProvider);
      final ok = await launchUrl(Uri.parse('${r['url']}'), mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && mounted) _say('Could not open the class. Install Zoom or Google Meet and try again.');
      return;
    }
    _say(switch ('${r['error']}') {
      'early' => 'The class opens 15 minutes before it starts.',
      'ended' => 'This class has ended.',
      'no_link' => 'The teacher has not added the link yet. Try again in a minute.',
      'no_recording' => 'The recording is not ready yet.',
      'premium' || 'locked' => 'This class is for Premium students.',
      'pay' => 'Register and pay to join this class.',
      'pay_program' => 'Join the class first to attend its sessions.',
      _ => 'You cannot join this class.',
    });
    if ('${r['error']}' == 'pay_program' && r['program_id'] != null && mounted) context.push('/classes/program/${r['program_id']}');
  });

  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final list = ref.watch(classesProvider);
    return Scaffold(
      appBar: const TopBar(title: 'Live class'),
      body: asyncView(list, (all) {
        final x = all.where((c) => c['id'] == widget.id).firstOrNull;
        if (x == null) {
          return StateBlock(
            icon: PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
            title: 'This class is not available',
            text: 'It may have been moved or removed.',
            action: Btn('See all classes', kind: BtnKind.outline, onPressed: () => context.pushReplacement('/classes')),
          );
        }
        final now = DateTime.now();
        final phase = classPhase(x, now);
        final allowed = x['allowed'] == true, registered = x['registered'] == true;
        final seats = (x['seats'] as num?)?.toInt(), taken = (x['taken'] as num?)?.toInt() ?? 0;
        final Widget action = switch (phase) {
          ClassPhase.cancelled => const Btn('This class was cancelled', block: true, kind: BtnKind.outline),
          ClassPhase.ended =>
            x['has_recording'] == true
                ? Btn(
                    allowed ? 'Watch the recording' : 'Recording for registered students',
                    block: true,
                    loading: _busy,
                    icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                    onPressed: allowed ? () => _open('class_recording') : null,
                  )
                : const Btn('This class has ended', block: true, kind: BtnKind.outline),
          ClassPhase.live =>
            allowed || registered
                ? Btn(
                    'Join the class now',
                    block: true,
                    kind: BtnKind.accent,
                    loading: _busy,
                    icon: PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
                    onPressed: () => _open('class_join'),
                  )
                : _registerBtn(x),
          ClassPhase.upcoming =>
            registered || (x['program_id'] != null && allowed)
                ? Btn('Registered · opens 15 min before', block: true, kind: BtnKind.tonal, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill))
                : _registerBtn(x),
        };
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
                children: [
                  _SessionHero(x: x, phase: phase),
                  const Gap(Space.s4),
                  ListCard(
                    children: [
                      ListRow(
                        icon: PhosphorIcons.calendar(PhosphorIconsStyle.fill),
                        title: classWhen(x),
                        caption: '${x['minutes']} minutes · Lagos time',
                        caret: false,
                      ),
                      ListRow(
                        icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill),
                        tone: Tone.gold,
                        title: x['program_id'] != null
                            ? (allowed ? 'Part of ${x['program_title']} · you are in' : 'Part of ${x['program_title']}')
                            : switch ('${x['access']}') {
                                'premium' => 'Free for Premium students',
                                'paid' => 'Paid class · ${accessLabel(x)}',
                                _ => 'Free class',
                              },
                        caption: seats == null ? null : '${(seats - taken).clamp(0, seats)} of $seats seats left',
                        caret: false,
                      ),
                      if (phase == ClassPhase.upcoming)
                        ListRow(
                          icon: PhosphorIcons.bellRinging(PhosphorIconsStyle.fill),
                          tone: Tone.green,
                          title: 'Reminders',
                          caption: '2 h, 1 h, 30, 10 and 3 minutes before, and at the start',
                          caret: false,
                        ),
                    ],
                  ),
                  if ('${x['about'] ?? ''}'.trim().isNotEmpty) ...[
                    const Gap(Space.s5),
                    const SectTitle('What we will cover'),
                    Text('${x['about']}', style: context.ty.body),
                  ],
                  const Gap(Space.s5),
                  Text(
                    'The class opens in Zoom or Google Meet. Join on Wi-Fi if you can: an hour of video uses about 300–500 MB.',
                    style: context.ty.cap.col(col.textSubtle),
                  ),
                ],
              ),
            ),
            FooterCta(child: action),
          ],
        );
      }, onRetry: () => ref.invalidate(classesProvider)),
    );
  }

  Widget _registerBtn(Map<String, dynamic> x) {
    if (x['program_id'] != null && x['allowed'] != true) {
      return Btn(
        'See ${x['program_title'] ?? 'the class'} and join',
        block: true,
        kind: BtnKind.accent,
        onPressed: () => context.push('/classes/program/${x['program_id']}'),
      );
    }
    final seats = (x['seats'] as num?)?.toInt(), taken = (x['taken'] as num?)?.toInt() ?? 0;
    if (seats != null && taken >= seats) return const Btn('This class is full', block: true, kind: BtnKind.outline);
    return switch ('${x['access']}') {
      'paid' => Btn(
        usesPaystack(ref) ? 'Register and pay ${accessLabel(x)}' : 'Register on the SolutionTee website',
        block: true,
        kind: BtnKind.accent,
        loading: _busy,
        onPressed: () => _run(() => _pay(x)),
      ),
      'premium' when x['allowed'] != true => Btn(
        'Go Premium to join',
        block: true,
        kind: BtnKind.accent,
        leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
        onPressed: () => showPaywall(context, reason: 'classes'),
      ),
      _ => Btn('Register for free', block: true, loading: _busy, onPressed: () => _register(x)),
    };
  }
}

// ---------------------------------------------------------------------------------------------------- programmes (D-163)

String programPrice(Map<String, dynamic> p) => switch ('${p['access']}') {
  'premium' => 'Premium',
  'paid' => naira((p['price_kobo'] as num?)?.toInt() ?? 0),
  _ => 'Free',
};

/// The classes to buy once (flyer cards), above the sessions list.
class _ProgramsSection extends ConsumerWidget {
  const _ProgramsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(programsProvider).value ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectTitle('Classes'),
        for (final (i, p) in list.indexed) ...[
          rm
              ? ProgramCard(p: p)
              : ProgramCard(p: p).animate().fadeIn(delay: (60 * i).ms, duration: Motion.base).slideY(begin: .06, end: 0, curve: Curves.easeOutCubic),
          const Gap(Space.s3),
        ],
        const Gap(Space.s3),
      ],
    );
  }
}

/// A class programme: flyer, name, when it holds, price or "You are in", and the next session (LIVE or a countdown).
class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.p});
  final Map<String, dynamic> p;
  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final next = p['next'] is Map ? Map<String, dynamic>.from(p['next'] as Map) : null;
    final start = next == null ? null : DateTime.tryParse('${next['starts_at']}')?.toLocal();
    final live = next?['live'] == true;
    final inClass = p['allowed'] == true || p['enrolled'] == true;
    final flyer = '${p['flyer_path'] ?? ''}';
    return AppCard(
      pad: false,
      clip: true,
      onTap: () => context.push('/classes/program/${p['id']}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Palette.navy900, Palette.blue600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                  ),
                  if (flyer.isNotEmpty) R2Image(imageKey: flyer, decodeWidth: 360, semanticLabel: '${p['title']} flyer'),
                  if (flyer.isEmpty) Center(child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 36, color: Palette.gold300)),
                  if (live) const Positioned(left: 8, top: 8, child: LivePulse(small: true)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ('${p['exam'] ?? ''}'.isNotEmpty)
                      Text('${p['exam']}'.toUpperCase(), style: context.ty.cap.bold.copyWith(letterSpacing: 1).col(col.onSecondarySoft)),
                    Text('${p['title']}', style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if ('${p['schedule_note'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('${p['schedule_note']}', style: context.ty.cap.col(col.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: Space.s2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (inClass)
                          Pill('You are in', kind: BadgeKind.success, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill))
                        else
                          Pill(programPrice(p), kind: p['access'] == 'free' ? BadgeKind.success : (p['access'] == 'premium' ? BadgeKind.gold : BadgeKind.soft)),
                        if (!inClass && p['seats_left'] is num && (p['seats_left'] as num) > 0 && (p['seats_left'] as num) <= 30)
                          Pill('${p['seats_left']} seats left', kind: BadgeKind.warning),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: Space.s2),
                    if (start != null && !live)
                      Row(
                        children: [
                          Icon(PhosphorIcons.clock(PhosphorIconsStyle.fill), size: 14, color: col.textMuted),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Next session ${classIn(next!, DateTime.now())}', style: context.ty.cap.bold.col(col.textMuted))),
                        ],
                      )
                    else if (live)
                      Text('A session is live now', style: context.ty.cap.bold.col(const Color(0xFFE5484D)))
                    else
                      Text('${p['sessions_done'] ?? 0} sessions so far', style: context.ty.cap.col(col.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One programme: flyer, the next session with a big countdown (or LIVE + Join), what students get, the timetable,
/// the teacher, questions, and the one action that fits (pay once, join for free, go Premium, join live).
class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  bool _busy = false;
  late final Timer _tick = Timer.periodic(const Duration(seconds: 20), (_) => mounted ? setState(() {}) : null);

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _say(String m, [IconData? icon]) => toast(context, m, icon: icon ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) _say('Could not reach SolutionTee. Check your internet and try again.', PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(programProvider(widget.id));
    ref.invalidate(programsProvider);
    ref.invalidate(classesProvider);
  }

  Future<void> _pay(Map<String, dynamic> p) => _run(() async {
    if (!usesPaystackNow(ref)) {
      await launchUrl(Uri.parse('https://cbt.solutiontee.com/classes/${p['slug']}'), mode: LaunchMode.externalApplication);
      return;
    }
    final r = await payForItem(context, ref, itemRef: widget.id, title: '${p['title']}', priceKobo: (p['price_kobo'] as num?)?.toInt() ?? 0);
    if (!mounted) return;
    switch (r) {
      case PaySuccess():
        _refresh();
        _say('You are in! Join every session of this class. We will remind you before each one.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      case PayFailed(:final message):
        _say(message, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
      case PayCancelled():
        _say('Payment cancelled. You were not charged.');
      case PayPending():
        _say('We are waiting for Paystack. You are in as soon as the payment is confirmed.', PhosphorIcons.clock(PhosphorIconsStyle.fill));
      default:
        break;
    }
  });

  Future<void> _register() => _run(() async {
    final r = Map<String, dynamic>.from(
      await Supabase.instance.client.rpc('program_register', params: {'p_program': widget.id}).timeout(const Duration(seconds: 15)) as Map,
    );
    if (!mounted) return;
    if (r['ok'] == true) {
      _refresh();
      return _say('You are in! We will remind you before each session.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    }
    switch ('${r['error']}') {
      case 'premium':
        await showPaywall(context, reason: 'classes');
      case 'full':
        _say('This class is full.');
      default:
        _say('You cannot join this class right now.');
    }
  });

  Future<void> _join(String sessionId) => _run(() async {
    final r = Map<String, dynamic>.from(
      await Supabase.instance.client.rpc('class_join', params: {'p_class': sessionId}).timeout(const Duration(seconds: 15)) as Map,
    );
    if (!mounted) return;
    if (r['ok'] == true && '${r['url']}'.startsWith('https://')) {
      final ok = await launchUrl(Uri.parse('${r['url']}'), mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && mounted) _say('Could not open the class. Install Zoom or Google Meet and try again.');
      return;
    }
    _say(switch ('${r['error']}') {
      'early' => 'The session opens 15 minutes before it starts.',
      'ended' => 'This session has ended.',
      'no_link' => 'The teacher has not added the link yet. Try again in a minute.',
      _ => 'You cannot join this session.',
    });
  });

  @override
  Widget build(BuildContext context) {
    _tick;
    final col = context.c;
    final rm = context.reduceMotion;
    return Scaffold(
      appBar: const TopBar(title: 'Class'),
      body: asyncView(ref.watch(programProvider(widget.id)), (p) {
        if (p == null) {
          return StateBlock(
            icon: PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
            title: 'This class is not available',
            text: 'It may have been closed or removed.',
            action: Btn('See all classes', kind: BtnKind.outline, onPressed: () => context.pushReplacement('/classes')),
          );
        }
        final inClass = p['allowed'] == true || p['enrolled'] == true;
        final next = p['next'] is Map ? Map<String, dynamic>.from(p['next'] as Map) : null;
        final start = next == null ? null : classStart(next), end = next == null ? null : classEnd(next);
        final now = DateTime.now();
        final live = next != null && classPhase(next, now) == ClassPhase.live;
        final sessions = [for (final x in (p['sessions'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        final highlights = [for (final h in (p['highlights'] as List? ?? const [])) '$h'];
        final faq = [for (final f in (p['faq'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
        final flyer = '${p['flyer_path'] ?? ''}';
        final compare = (p['compare_kobo'] as num?)?.toInt();
        final price = (p['price_kobo'] as num?)?.toInt() ?? 0;

        final Widget action = live && inClass
            ? Btn(
                'Join the live session now',
                block: true,
                kind: BtnKind.accent,
                loading: _busy,
                icon: PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
                onPressed: () => _join('${next['id']}'),
              )
            : inClass
            ? Btn(
                next == null ? 'You are in this class' : 'You are in · next session ${classIn(next, now)}',
                block: true,
                kind: BtnKind.tonal,
                icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              )
            : p['access'] == 'paid'
            ? (p['buyable'] == true
                  ? Btn(
                      usesPaystack(ref) ? 'Pay ${naira(price)} once · join every session' : 'Join on the SolutionTee website',
                      block: true,
                      kind: BtnKind.accent,
                      loading: _busy,
                      onPressed: () => _pay(p),
                    )
                  : Btn(p['seats_left'] == 0 ? 'This class is full' : 'Not taking new students now', block: true, kind: BtnKind.outline))
            : p['access'] == 'premium'
            ? Btn(
                'Go Premium to join',
                block: true,
                kind: BtnKind.accent,
                leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                onPressed: () => showPaywall(context, reason: 'classes'),
              )
            : Btn('Join for free', block: true, loading: _busy, onPressed: _register);

        Widget enter(Widget w, int i) =>
            rm ? w : w.animate().fadeIn(delay: (70 * i).ms, duration: Motion.base).slideY(begin: .05, end: 0, curve: Curves.easeOutCubic);

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
                  children: [
                    // The admin's flyer, whole (flyers carry their own text), with the name under it.
                    enter(
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.lg + 4),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [Palette.navy900, Palette.blue600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                ),
                                child: flyer.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(Space.s6),
                                          child: Text('${p['title']}', textAlign: TextAlign.center, style: context.ty.h1.col(Colors.white)),
                                        ),
                                      )
                                    : null,
                              ),
                              if (flyer.isNotEmpty) R2Image(imageKey: flyer, decodeWidth: 900, semanticLabel: '${p['title']} flyer'),
                              if (live)
                                const Positioned(
                                  left: Space.s3,
                                  top: Space.s3,
                                  child: LivePulse(text: 'LIVE NOW'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      0,
                    ),
                    const SizedBox(height: Space.s4),
                    enter(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ('${p['exam'] ?? ''}'.isNotEmpty)
                            Text(
                              ['${p['exam']}', if ('${p['subjects'] ?? ''}'.isNotEmpty) '${p['subjects']}'].join(' · ').toUpperCase(),
                              style: context.ty.cap.bold.copyWith(letterSpacing: .8).col(context.c.textMuted),
                            ),
                          const SizedBox(height: 4),
                          Text('${p['title']}', style: context.ty.h1),
                          if ('${p['tagline'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${p['tagline']}', style: context.ty.body.col(context.c.textMuted)),
                          ],
                        ],
                      ),
                      1,
                    ),
                    const Gap(Space.s4),
                    // The next session, counting down.
                    if (next != null && start != null && end != null)
                      enter(
                        Container(
                          padding: const EdgeInsets.all(Space.s4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(Radii.lg),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                live ? 'LIVE SESSION' : 'NEXT SESSION',
                                style: context.ty.cap.bold.copyWith(letterSpacing: 1).col(live ? const Color(0xFFFF8A8E) : const Color(0xFFB9C7DE)),
                              ),
                              const SizedBox(height: 4),
                              Text('${next['title']}', style: context.ty.body.bold.col(Colors.white)),
                              Text(classWhen(next), style: context.ty.cap.col(const Color(0xFFB9C7DE))),
                              const SizedBox(height: Space.s3),
                              ClassCountdown(to: start, endsAt: end, big: true, dark: true),
                            ],
                          ),
                        ),
                        1,
                      ),
                    if (next != null) const Gap(Space.s4),
                    // Price (when not in yet).
                    if (!inClass && p['access'] == 'paid')
                      enter(
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(naira(price), style: context.ty.display.tnum),
                                  if (compare != null && compare > price) ...[
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(naira(compare), style: context.ty.body.col(col.textMuted).copyWith(decoration: TextDecoration.lineThrough)),
                                    ),
                                  ],
                                ],
                              ),
                              Text('One payment. Join every session live, and watch the recordings.', style: context.ty.sm.col(col.textMuted)),
                              if (p['seats_left'] is num && (p['seats_left'] as num) > 0 && (p['seats_left'] as num) <= 30) ...[
                                const SizedBox(height: 6),
                                Text('Only ${p['seats_left']} seats left', style: context.ty.sm.bold.col(Palette.amber600)),
                              ],
                            ],
                          ),
                        ),
                        2,
                      ),
                    if (!inClass && p['access'] == 'paid') const Gap(Space.s4),
                    ListCard(
                      children: [
                        if ('${p['schedule_note'] ?? ''}'.isNotEmpty)
                          ListRow(icon: PhosphorIcons.calendar(PhosphorIconsStyle.fill), title: '${p['schedule_note']}', caption: 'Lagos time', caret: false),
                        if ('${p['teacher'] ?? ''}'.isNotEmpty)
                          ListRow(
                            icon: PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
                            tone: Tone.gold,
                            title: 'with ${p['teacher']}',
                            caption: '${p['teacher_bio'] ?? ''}'.trim().isEmpty ? null : '${p['teacher_bio']}',
                            caret: false,
                          ),
                        ListRow(
                          icon: PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
                          tone: Tone.green,
                          title: '${(p['sessions_left'] as num? ?? 0) + (p['sessions_done'] as num? ?? 0)} live sessions',
                          caption: 'Reminders before each one · recordings after',
                          caret: false,
                        ),
                      ],
                    ),
                    if (highlights.isNotEmpty) ...[
                      const Gap(Space.s5),
                      const SectTitle('What you get'),
                      for (final h in highlights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 20, color: col.success),
                              const SizedBox(width: Space.s2),
                              Expanded(child: Text(h, style: context.ty.body)),
                            ],
                          ),
                        ),
                    ],
                    if ('${p['about'] ?? ''}'.trim().isNotEmpty) ...[
                      const Gap(Space.s4),
                      const SectTitle('About this class'),
                      Text('${p['about']}', style: context.ty.body),
                    ],
                    if (sessions.isNotEmpty) ...[
                      const Gap(Space.s5),
                      const SectTitle('Sessions'),
                      for (final (i, x) in sessions.indexed) _SessionStep(x: x, last: i == sessions.length - 1, allowed: inClass),
                    ],
                    if (faq.isNotEmpty) ...[
                      const Gap(Space.s5),
                      const SectTitle('Questions'),
                      for (final f in faq)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('${f['q']}', style: context.ty.body.bold),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('${f['a']}', style: context.ty.sm.col(col.textMuted)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            FooterCta(child: action),
          ],
        );
      }, onRetry: () => ref.invalidate(programProvider(widget.id))),
    );
  }
}

/// A session in the programme timeline: done (tick), live (red), or coming (its date).
class _SessionStep extends StatelessWidget {
  const _SessionStep({required this.x, required this.last, required this.allowed});
  final Map<String, dynamic> x;
  final bool last, allowed;
  @override
  Widget build(BuildContext context) {
    final col = context.c;
    final phase = classPhase(x, DateTime.now());
    final (Color dot, IconData icon) = switch (phase) {
      ClassPhase.live => (const Color(0xFFE5484D), PhosphorIcons.videoCamera(PhosphorIconsStyle.fill)),
      ClassPhase.ended => (col.success, PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
      ClassPhase.cancelled => (col.textSubtle, PhosphorIcons.xCircle(PhosphorIconsStyle.fill)),
      ClassPhase.upcoming => (col.secondary, PhosphorIcons.calendar(PhosphorIconsStyle.fill)),
    };
    return InkWell(
      onTap: () => context.push('/classes/${x['id']}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: dot.withValues(alpha: .14), shape: BoxShape.circle),
                    child: Icon(icon, size: 16, color: dot),
                  ),
                  if (!last) Expanded(child: Container(width: 2, color: col.border)),
                ],
              ),
            ),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${x['title']}', style: context.ty.sm.bold),
                    Text(
                      phase == ClassPhase.live
                          ? 'Live now'
                          : phase == ClassPhase.ended
                          ? (x['has_recording'] == true && allowed ? '${classWhen(x)} · recording ready' : classWhen(x))
                          : '${classWhen(x)} · ${x['minutes']} min',
                      style: context.ty.cap.col(phase == ClassPhase.live ? const Color(0xFFE5484D) : col.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top of a session screen: programme, title, teacher, and a big countdown to the start (or to the end while live).
class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.x, required this.phase});
  final Map<String, dynamic> x;
  final ClassPhase phase;
  @override
  Widget build(BuildContext context) {
    final start = classStart(x), end = classEnd(x);
    final live = phase == ClassPhase.live;
    final w = Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Radii.lg + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (live)
                const LivePulse()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                  child: Text(switch (phase) {
                    ClassPhase.ended => 'ENDED',
                    ClassPhase.cancelled => 'CANCELLED',
                    _ => 'COMING UP',
                  }, style: context.ty.cap.bold.copyWith(letterSpacing: 1).col(Colors.white)),
                ),
              const Spacer(),
              Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), color: Palette.gold300, size: 22),
            ],
          ),
          const SizedBox(height: Space.s3),
          if ('${x['program_title'] ?? ''}'.isNotEmpty) Text('${x['program_title']}', style: context.ty.cap.bold.col(Palette.gold300)),
          Text('${x['title']}', style: context.ty.h2.col(Colors.white)),
          const SizedBox(height: 2),
          Text('with ${x['teacher']} · ${classWhen(x)}', style: context.ty.sm.col(const Color(0xFFB9C7DE))),
          if (start != null && end != null && (phase == ClassPhase.upcoming || live)) ...[
            const SizedBox(height: Space.s4),
            ClassCountdown(to: start, endsAt: end, big: true, dark: true),
          ],
        ],
      ),
    );
    return context.reduceMotion ? w : w.animate().fadeIn(duration: Motion.base).slideY(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }
}
