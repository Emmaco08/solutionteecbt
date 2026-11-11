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
import '../../widgets/states.dart';
import '../premium/item_pay.dart';
import '../premium/payments.dart';
import '../premium/paywall.dart';

// Online classes (C13, D-147). The list never carries a class link: the server hands it out (class_join) only to a
// student who may come in, from 15 minutes before the start until the end.

final classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'classes:$uid', (s) => s.rpc('classes_list'), rows);
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

/// Home / Study card: the next class with a countdown.
class NextClassCard extends ConsumerWidget {
  const NextClassCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final list = ref.watch(classesProvider).value ?? const <Map<String, dynamic>>[];
    final now = DateTime.now();
    final x = nextClass(list, now);
    if (x == null) return const SizedBox.shrink();
    final live = classPhase(x, now) == ClassPhase.live;
    return AppCard(
      onTap: () => context.push('/classes/${x['id']}'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), tone: live ? Tone.red : Tone.blue, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live ? 'Live class now' : 'Next live class ${classIn(x, now)}',
                  style: context.ty.cap.bold.col(live ? const Color(0xFFE5484D) : c.textMuted),
                ),
                Text('${x['title']}', style: context.ty.body.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${classWhen(x)} · ${x['teacher']}', style: context.ty.cap.col(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
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
          await ref.read(classesProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
        },
        child: asyncView(ref.watch(classesProvider), (list) {
          final now = DateTime.now();
          final live = list.where((x) => classPhase(x, now) == ClassPhase.live).toList();
          final soon = list.where((x) => classPhase(x, now) == ClassPhase.upcoming).toList();
          final past = list.where((x) => classPhase(x, now) == ClassPhase.ended).toList().reversed.toList();
          if (live.isEmpty && soon.isEmpty && past.isEmpty) {
            return ListView(
              children: [
                StateBlock(
                  icon: PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
                  tone: Tone.blue,
                  title: 'No classes yet',
                  text: 'Live classes with our teachers show here. We will tell you when the next one is posted.',
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
                Text('${c['title']}', style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Gap(2),
                Text('${c['teacher']} · ${c['minutes']} min', style: context.ty.cap.col(col.textMuted)),
                const Gap(Space.s1),
                Wrap(
                  spacing: Space.s1,
                  runSpacing: Space.s1,
                  children: [
                    Pill(accessLabel(c), kind: c['access'] == 'free' ? BadgeKind.success : (c['access'] == 'premium' ? BadgeKind.gold : BadgeKind.soft)),
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
      _ => 'You cannot join this class.',
    });
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
            registered
                ? Btn('Registered · opens 15 min before', block: true, kind: BtnKind.tonal, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill))
                : _registerBtn(x),
        };
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s6),
                children: [
                  Row(
                    children: [
                      _DateBox(c: x, live: phase == ClassPhase.live),
                      const Gap(Space.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${x['title']}', style: context.ty.h2),
                            const Gap(2),
                            Text('with ${x['teacher']}', style: context.ty.sm.col(col.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        title: switch ('${x['access']}') {
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
