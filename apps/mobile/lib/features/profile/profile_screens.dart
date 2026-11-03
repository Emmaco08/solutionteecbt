import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../home/home_screen.dart';
import '../premium/checkout.dart';
import '../premium/payments.dart';

const _supportEmailFallback = 'support@mail.solutiontee.com';

/// Finished tests on this phone, newest first.
final historyProvider = FutureProvider.autoDispose<List<LocalAttempt>>((ref) => ref.watch(dbProvider).finishedAttempts());

Map<String, dynamic>? _score(LocalAttempt a) {
  final raw = a.serverScoreJson ?? a.clientScoreJson;
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

int _pct(Map<String, dynamic> s) {
  final q = (s['questions'] as num?)?.toInt() ?? 0;
  return q == 0 ? 0 : (100 * (s['correct'] as num) / q).round();
}

bool _jambFull(LocalAttempt a) => a.examCode == 'JAMB' && a.mode == 'full';

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Clears everything this account left on the phone, then signs out. Order matters: signing out makes the
/// router leave this screen at once, after which `ref` can no longer be used.
Future<void> signOutAndWipe(WidgetRef ref) async {
  final db = ref.read(dbProvider);
  await db.wipe();
  // Local lists re-read the now-empty database; account data (profile, plan, years) follows the login state by itself.
  for (final p in [historyProvider, unfinishedProvider, practiceStatsProvider]) {
    ref.invalidate(p);
  }
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {
    // Offline: Supabase still removes the session from this phone.
  }
}

Future<void> _open(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Could not open that. Please try again.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
}

Widget _stagger(BuildContext context, List<Widget> children, {double gap = Space.s5}) {
  final rm = context.reduceMotion;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Gap(gap),
        rm ? children[i] : children[i].animate(delay: Motion.stagger * i.clamp(0, 8)).fadeIn(duration: Motion.slow).slideY(begin: .06, curve: Motion.out),
      ],
    ],
  );
}

/// Stat card (`.card.stat`): big number + small bold label.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          child: Text(value, style: context.ty.h2.copyWith(fontSize: 22, height: 28 / 22).tnum),
        ),
        Text(label, style: context.ty.cap.bold.col(context.c.textMuted)),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Me (prototype: profile)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(myPlanProvider).value;
    final premium = plan?['tier'] == 'premium';
    final expires = DateTime.tryParse((plan?['expires_at'] as String?) ?? '')?.toLocal();
    final history = ref.watch(historyProvider).value ?? const [];
    final stats = ref.watch(practiceStatsProvider).value;
    final subjects = ref.watch(subjectsProvider).value ?? const [];

    final best = history
        .where(_jambFull)
        .map(_score)
        .whereType<Map<String, dynamic>>()
        .map((s) => (s['total'] as num).toInt())
        .fold<int?>(null, (m, v) => m == null || v > m ? v : m);
    final minutes = history.fold<int>(0, (t, a) => t + a.usedMs) ~/ 60000;
    final trend = [for (final a in history.where(_jambFull).toList().reversed) (_score(a)?['total'] as num?)?.toInt()].whereType<int>().toList();
    final bySubject = <int, List<int>>{};
    for (final a in history) {
      for (final x in (_score(a)?['subjects'] as List?) ?? const []) {
        final m = Map<String, dynamic>.from(x as Map);
        bySubject.putIfAbsent((m['subject_id'] as num).toInt(), () => []).add((m['score'] as num).toInt());
      }
    }
    String subjName(int id) {
      final n = (subjects.where((s) => s['id'] == id).firstOrNull?['name'] as String?) ?? 'Subject';
      return n == 'Use of English' ? 'English' : n;
    }

    return Scaffold(
      appBar: TopBar(
        showBack: false,
        center: Padding(
          padding: const EdgeInsets.only(left: Space.s3),
          child: Text('Me', style: context.ty.h2),
        ),
        actions: [IconBtn(PhosphorIcons.gearSix(), label: 'Settings', onPressed: () => context.push('/settings'))],
      ),
      body: asyncView(profile, (p) {
        final name = (p?['full_name'] as String?) ?? '';
        final target = p?['target_score'];
        final line = [if (p?['state'] != null) p!['state'] as String, if (target != null) 'JAMB target $target'].join(' · ');
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(myPlanProvider);
            ref.invalidate(historyProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.s8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s4),
                child: Row(
                  children: [
                    Avatar(name, size: 72),
                    const Gap(Space.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(name.isEmpty ? 'Student' : name, style: context.ty.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              IconBtn(
                                PhosphorIcons.pencilSimple(),
                                label: 'Edit my details',
                                size: 18,
                                color: c.textMuted,
                                onPressed: () => context.push('/edit-profile'),
                              ),
                            ],
                          ),
                          if (line.isNotEmpty) Text(line, style: context.ty.sm.col(c.textMuted)),
                          const Gap(Space.s2),
                          premium
                              ? Pill(
                                  'Premium${expires == null ? '' : ' · until ${_date(expires)}'}',
                                  kind: BadgeKind.gold,
                                  icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                                )
                              : const Pill('Free plan', kind: BadgeKind.neutral),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                child: _stagger(context, [
                  if (premium)
                    AppCard(
                      child: Row(
                        children: [
                          IconTile(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12, iconSize: 22),
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Premium is active', style: context.ty.body.bold),
                                if (expires != null) Text('Ends ${_date(expires)}', style: context.ty.cap.col(c.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const UpgradeBanner(title: 'Upgrade to Premium', text: 'Every year, videos, notes, novels and more AI help.'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Space.s3,
                    crossAxisSpacing: Space.s3,
                    childAspectRatio: 2.2,
                    children: [
                      _Stat(value: '${history.length}', label: 'Tests taken'),
                      _Stat(value: best == null ? '–' : '$best', label: 'Best JAMB score'),
                      _Stat(value: '${stats?.streak ?? 0} day${stats?.streak == 1 ? '' : 's'}', label: 'Current streak'),
                      _Stat(value: minutes >= 60 ? '${minutes ~/ 60}h ${minutes % 60}m' : '${minutes}m', label: 'Time practising'),
                    ],
                  ),
                  if (trend.length >= 2)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Score trend', style: context.ty.h3)),
                              Builder(
                                builder: (context) {
                                  final d = trend.last - trend.first;
                                  return Pill(
                                    '${d >= 0 ? '+' : ''}$d',
                                    kind: d >= 0 ? BadgeKind.success : BadgeKind.error,
                                    icon: d >= 0 ? PhosphorIcons.trendUp(PhosphorIconsStyle.fill) : PhosphorIcons.trendDown(PhosphorIconsStyle.fill),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Gap(Space.s2),
                          Semantics(
                            label: 'JAMB score trend from ${trend.first} to ${trend.last}',
                            child: SizedBox(
                              height: 130,
                              child: CustomPaint(
                                painter: _TrendChart(trend, line: c.secondary, grid: c.border, axis: c.textSubtle, dot: c.accent, surface: c.surface),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (bySubject.isNotEmpty)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Average by subject', style: context.ty.h3),
                          for (final e in bySubject.entries) ...[
                            const Gap(Space.s3),
                            Builder(
                              builder: (context) {
                                final avg = (e.value.reduce((a, b) => a + b) / e.value.length).round();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(subjName(e.key), style: context.ty.sm.bold)),
                                        Text('$avg%', style: context.ty.sm.tnum.col(c.textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ProgressBar(avg / 100, color: avg >= 70 ? c.success : null),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ListCard(
                    children: [
                      ListRow(icon: PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill), title: 'Test history', onTap: () => context.push('/history')),
                      if (showsRedeem(ref))
                        ListRow(icon: PhosphorIcons.ticket(PhosphorIconsStyle.fill), title: 'Redeem a code', onTap: () => showRedeemSheet(context)),
                      ListRow(icon: PhosphorIcons.gearSix(PhosphorIconsStyle.fill), title: 'Settings', onTap: () => context.push('/settings')),
                      ListRow(icon: PhosphorIcons.question(PhosphorIconsStyle.fill), title: 'Help & support', onTap: () => context.push('/help')),
                    ],
                  ),
                  Btn(
                    'Log out',
                    kind: BtnKind.outline,
                    block: true,
                    leading: PhosphorIcons.signOut(),
                    onPressed: () async {
                      final ok = await showAppDialog<bool>(
                        context,
                        title: 'Log out?',
                        body: 'Tests saved on this phone will be removed. Tests already sent to SolutionTee stay in your account.',
                        actions: [
                          Builder(
                            builder: (ctx) => Row(
                              children: [
                                Expanded(
                                  child: Btn('Cancel', kind: BtnKind.outline, block: true, onPressed: () => Navigator.pop(ctx, false)),
                                ),
                                const Gap(Space.s3),
                                Expanded(child: Btn('Log out', block: true, onPressed: () => Navigator.pop(ctx, true))),
                              ],
                            ),
                          ),
                        ],
                      );
                      if (ok == true) {
                        await signOutAndWipe(ref);
                        if (context.mounted) context.go('/welcome');
                      }
                    },
                  ),
                ]),
              ),
            ],
          ),
        );
      }, onRetry: () => ref.invalidate(profileProvider)),
    );
  }
}

/// Score trend line (prototype `chart()`): grid lines at 200/250/300, area, line, dots, last dot in gold.
class _TrendChart extends CustomPainter {
  _TrendChart(this.pts, {required this.line, required this.grid, required this.axis, required this.dot, required this.surface});
  final List<int> pts;
  final Color line, grid, axis, dot, surface;
  @override
  void paint(Canvas canvas, Size size) {
    const pad = 28.0, bottom = 8.0;
    final lo = (pts.reduce((a, b) => a < b ? a : b) - 20).clamp(0, 400).toDouble();
    final hi = (pts.reduce((a, b) => a > b ? a : b) + 20).clamp(0, 400).toDouble();
    double y(num v) => size.height - bottom - (v - lo) / (hi - lo == 0 ? 1 : hi - lo) * (size.height - bottom - 8);
    final xy = [for (var i = 0; i < pts.length; i++) Offset(pad + i * (size.width - pad - 6) / (pts.length - 1), y(pts[i]))];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final g in [lo + (hi - lo) * .2, lo + (hi - lo) * .5, lo + (hi - lo) * .8]) {
      canvas.drawLine(Offset(pad, y(g)), Offset(size.width - 6, y(g)), Paint()..color = grid);
      tp.text = TextSpan(
        text: '${g.round()}',
        style: TextStyle(fontFamily: kFont, fontSize: 10, color: axis),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y(g) - 6));
    }
    final path = Path()..moveTo(xy.first.dx, xy.first.dy);
    for (final p in xy.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(xy.last.dx, size.height - bottom)
      ..lineTo(xy.first.dx, size.height - bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: .1));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < xy.length; i++) {
      final last = i == xy.length - 1;
      canvas.drawCircle(xy[i], last ? 5 : 3.5, Paint()..color = last ? dot : surface);
      if (!last) {
        canvas.drawCircle(
          xy[i],
          3.5,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrendChart old) => old.pts != pts || old.line != line;
}

// ---------------------------------------------------------------- edit details
/// Name, phone, state and school (the same fields as setup step 1).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController(), _phone = TextEditingController(), _school = TextEditingController();
  bool _busy = false;
  String? _nameErr;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).value;
    _name.text = (p?['full_name'] as String?) ?? '';
    _phone.text = (p?['phone'] as String?) ?? '';
    _school.text = (p?['school'] as String?) ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return setState(() => _nameErr = 'Enter your full name');
    setState(() {
      _busy = true;
      _nameErr = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _name.text.trim(),
            'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            'school': _school.text.trim().isEmpty ? null : _school.text.trim(),
          })
          .eq('id', uid);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      toast(context, 'Your details are saved.');
      context.pop();
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Check your internet and try again.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopBar(title: 'My details'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
      children: [
        Field(label: 'Full name', icon: PhosphorIcons.user(), controller: _name, caps: TextCapitalization.words, error: _nameErr),
        const Gap(Space.s4),
        Field(
          label: 'Phone number (optional)',
          icon: PhosphorIcons.phone(),
          controller: _phone,
          keyboard: TextInputType.phone,
          help: 'For class reminders only. We never share it.',
        ),
        const Gap(Space.s4),
        Field(label: 'School (optional)', icon: PhosphorIcons.graduationCap(), controller: _school, caps: TextCapitalization.words),
      ],
    ),
    bottomNavigationBar: FooterCta(
      child: Btn('Save', block: true, loading: _busy, onPressed: _save),
    ),
  );
}

// ---------------------------------------------------------------- history (prototype: history)
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final list = ref.watch(historyProvider);
    final n = list.value?.length ?? 0;
    return Scaffold(
      appBar: TopBar(title: 'Test history', subtitle: list.hasValue ? '$n test${n == 1 ? '' : 's'} on this phone' : null),
      body: asyncView(list, (list) {
        if (list.isEmpty) {
          return StateBlock(
            icon: PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill),
            tone: Tone.blue,
            title: 'No tests yet',
            text: 'Tests you finish on this phone will show here.',
            action: Btn('Start a test', onPressed: () => context.go('/test')),
          );
        }
        final scores = [for (final a in list) _score(a)].whereType<Map<String, dynamic>>().toList();
        final avg = scores.isEmpty ? 0 : (scores.map(_pct).reduce((a, b) => a + b) / scores.length).round();
        final best = list
            .where(_jambFull)
            .map(_score)
            .whereType<Map<String, dynamic>>()
            .map((s) => (s['total'] as num).toInt())
            .fold<int?>(null, (m, v) => m == null || v > m ? v : m);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
          children: [
            Row(
              children: [
                Expanded(
                  child: _Stat(value: '${list.length}', label: 'Tests'),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: _Stat(value: '$avg%', label: 'Average'),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: _Stat(value: best == null ? '–' : '$best', label: 'Best JAMB'),
                ),
              ],
            ),
            const Gap(Space.s4),
            ListCard(
              children: [
                for (final a in list)
                  Builder(
                    builder: (context) {
                      final s = _score(a);
                      final cfg = jsonDecode(a.configJson) as Map;
                      final scaled = a.examCode == 'JAMB' && (a.mode == 'full' || a.mode == 'subject');
                      final label = s == null ? '' : (scaled ? '${s['total']}/${s['max']}' : '${_pct(s)}%');
                      return ListRow(
                        icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
                        tone: Tone.blue,
                        title: (cfg['title'] as String?) ?? a.examCode,
                        caption: '${_date(a.submittedAt!.toLocal())}${a.synced ? '' : ' · not sent yet'}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: context.ty.sm.bold.tnum),
                            const SizedBox(width: 4),
                            Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
                          ],
                        ),
                        onTap: () => context.push('/results/${a.id}'),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------- settings (prototype: settings)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final c = context.c;
    Widget toggle(IconData ic, String title, String sub, bool v, ValueChanged<bool> on) => InkWell(
      onTap: () => on(!v),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
          child: Row(
            children: [
              IconTile(ic),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.ty.sm.bold),
                    Text(sub, style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
              const Gap(Space.s2),
              AppSwitch(value: v, onChanged: on),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: const TopBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          _stagger(context, [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Theme', style: context.ty.label),
                const Gap(Space.s2),
                Seg<ThemeMode>(
                  value: s.theme,
                  items: const [(ThemeMode.system, 'System'), (ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark')],
                  onChanged: (v) => n.update((x) => x.copyWith(theme: v)),
                ),
              ],
            ),
            ListCard(
              children: [
                toggle(
                  PhosphorIcons.personSimpleWalk(PhosphorIconsStyle.fill),
                  'Reduce motion',
                  'Fewer animations. Also follows your phone setting.',
                  s.reduceMotion,
                  (v) => n.update((x) => x.copyWith(reduceMotion: v)),
                ),
                toggle(
                  PhosphorIcons.cellSignalLow(PhosphorIconsStyle.fill),
                  'Data saver',
                  'Diagrams load only when you tap them.',
                  s.dataSaver,
                  (v) => n.update((x) => x.copyWith(dataSaver: v)),
                ),
              ],
            ),
            ListCard(
              children: [
                ListRow(icon: PhosphorIcons.books(PhosphorIconsStyle.fill), title: 'Change JAMB subjects', onTap: () => context.push('/subjects')),
                ListRow(
                  icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
                  title: 'Delete account',
                  danger: true,
                  onTap: () => context.push('/delete-account'),
                ),
              ],
            ),
            Text('SolutionTee CBT · version ${Config.appVersion}', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- help (prototype: help)
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    final support = (settings['support'] as Map?) ?? const {};
    final wa = (support['whatsapp_link'] as String?) ?? 'https://wa.me/2348122445948';
    final email = (support['email'] as String?) ?? _supportEmailFallback;
    final disclaimer = (settings['disclaimer'] as String?) ?? Config.disclaimer;
    Widget tile(IconData ic, Tone tone, String title, VoidCallback onTap) => AppCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104 - 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconTile(ic, tone: tone, size: 44, radius: 12, iconSize: 24),
            const Gap(Space.s3),
            Text(title, style: context.ty.sm.bold),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: const TopBar(title: 'Help & support'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          _stagger(context, [
            AppCard(
              onTap: () => context.go('/home?tour=1'),
              child: Row(
                children: [
                  IconTile(PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12, iconSize: 22),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replay the app tour', style: context.ty.body.bold),
                        Text('See where everything is again', style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                  Icon(PhosphorIcons.caretRight(), size: 20),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(child: tile(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), Tone.green, 'WhatsApp us', () => _open(context, Uri.parse(wa)))),
                const Gap(Space.s3),
                Expanded(
                  child: tile(
                    PhosphorIcons.envelopeSimple(PhosphorIconsStyle.fill),
                    Tone.blue,
                    'Email support',
                    () => _open(context, Uri(scheme: 'mailto', path: email, queryParameters: {'subject': 'SolutionTee CBT help'})),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Questions people ask', style: context.ty.label),
                const Gap(Space.s2),
                for (final (q, a) in const [
                  (
                    'Can I use the app without data?',
                    'Yes. Start a test once with internet so the questions download. You can then finish it offline, and your result syncs when you are back online.',
                  ),
                  (
                    'How is my JAMB score calculated?',
                    'Each subject is marked out of 100 and the four subjects are added to give a score out of 400, like the real UTME.',
                  ),
                  (
                    'What if my phone goes off during a test?',
                    'Every answer is saved as you tap it. Open the app and tap Continue your test on Home. The timer pauses while the app is closed.',
                  ),
                  (
                    'Why are some years locked?',
                    'Free accounts can open some years of each exam. Premium opens every year. Tap Upgrade to Premium on Home or Me to see the plans.',
                  ),
                ]) ...[_Faq(q: q, a: a), const Gap(Space.s2)],
              ],
            ),
            ListCard(
              children: [
                ListRow(icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill), title: 'Terms of Service', onTap: () => context.push('/legal?p=terms')),
                ListRow(icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), title: 'Privacy Policy', onTap: () => context.push('/legal?p=privacy')),
                ListRow(icon: PhosphorIcons.info(PhosphorIconsStyle.fill), title: 'About SolutionTee CBT', onTap: () => context.push('/legal?p=about')),
              ],
            ),
            Disclaimer(disclaimer),
          ]),
        ],
      ),
    );
  }
}

/// Accordion card (`.card.acc`).
class _Faq extends StatefulWidget {
  const _Faq({required this.q, required this.a});
  final String q, a;
  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => AppCard(
    pad: false,
    clip: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s4),
              child: Row(
                children: [
                  Expanded(child: Text(widget.q, style: context.ty.label)),
                  AnimatedRotation(turns: _open ? .5 : 0, duration: Motion.base, child: Icon(PhosphorIcons.caretDown(), size: 18)),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.out,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
                  child: Text(widget.a, style: context.ty.body.copyWith(fontSize: 14, height: 21 / 14).col(context.c.textMuted)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- terms / privacy / about (prototype: legal)
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.page});
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    final company = (settings['company'] as Map?) ?? const {};
    final disclaimer = (settings['disclaimer'] as String?) ?? Config.disclaimer;
    final (title, parts) = switch (page) {
      'privacy' => (
        'Privacy Policy',
        const [
          ('What we collect', 'Your name, email, phone (optional), school, state, exam choices, answers, scores, AI chats and payment records.'),
          ('Why', 'To run your account, show your progress, give AI help, prevent cheating and pay prizes. We never sell your data.'),
          (
            'Who we share with',
            'Our hosting and database provider, our AI provider (to answer your questions), Paystack and Google (for payments). Each only gets what it needs.',
          ),
          ('Your rights', 'You can see, correct or delete your data at any time in Me, Settings. We follow the Nigeria Data Protection Act 2023.'),
        ],
      ),
      'about' => (
        'About SolutionTee CBT',
        [
          (
            'Learn. Think. Solve.',
            'SolutionTee CBT helps Nigerian students prepare for JAMB, WAEC and NECO with real CBT practice, clear solutions and an AI tutor.',
          ),
          ('Independent', disclaimer),
          ('Company', [company['name'] ?? 'SolutionTee', company['rc_number'], company['address']].whereType<String>().join('\n')),
          ('Version', Config.appVersion),
          ('Contact', 'WhatsApp and email support from Me, Help.'),
        ],
      ),
      _ => (
        'Terms of Service',
        const [
          ('Using SolutionTee CBT', 'You must give true details when you sign up. Under 18? A parent or guardian must agree to these terms.'),
          ('Your account', 'One account per person and per phone. Do not share your login. We can suspend accounts that cheat or break these terms.'),
          (
            'Premium and payments',
            'Premium gives access for the time you paid for. Payments through Google Play follow Google’s refund rules; website payments follow our refund policy.',
          ),
          ('Challenges and prizes', 'Prizes are paid after a fair-play review and identity check. Leaving the challenge screen disqualifies an entry.'),
        ],
      ),
    };
    return Scaffold(
      appBar: TopBar(title: title, lined: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
        children: [
          if (page == 'about') ...[const Align(alignment: Alignment.centerLeft, child: Mark(height: 48)), const Gap(Space.s3)],
          if (page != 'about')
            InfoBanner(
              kind: BannerKind.warn,
              icon: PhosphorIcons.scales(PhosphorIconsStyle.fill),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Draft. ', style: context.ty.sm.bold.col(c.onWarningSoft)),
                    const TextSpan(text: 'To be reviewed by a lawyer before launch.'),
                  ],
                ),
              ),
            ),
          for (final (h, t) in parts) ...[
            const Gap(Space.s6),
            Text(h, style: context.ty.h2.copyWith(fontSize: 19, height: 26 / 19)),
            const Gap(Space.s2),
            Text(t, style: context.ty.body.copyWith(fontSize: 16, height: 27 / 16)),
          ],
          if (page == 'about') ...[
            const Gap(Space.s5),
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                ((company['website'] as String?) ?? 'https://solutiontee.com').replaceFirst('https://', ''),
                kind: BtnKind.ghost,
                icon: PhosphorIcons.arrowSquareOut(),
                onPressed: () => _open(context, Uri.parse((company['website'] as String?) ?? 'https://solutiontee.com')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- delete account (prototype: delete; Google Play requirement)
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final sure = await showAppDialog<bool>(
      context,
      title: 'Delete account now?',
      body: 'This cannot be undone.',
      actions: [
        Builder(
          builder: (ctx) => Row(
            children: [
              Expanded(
                child: Btn('Cancel', kind: BtnKind.outline, block: true, onPressed: () => Navigator.pop(ctx, false)),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Btn('Delete', kind: BtnKind.danger, block: true, onPressed: () => Navigator.pop(ctx, true)),
              ),
            ],
          ),
        ),
      ],
    );
    if (sure != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).deleteAccount();
      await signOutAndWipe(ref);
      if (!mounted) return;
      context.go('/welcome');
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) toast(context, 'Your account has been deleted.', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ready = _ctl.text.trim() == 'DELETE';
    return Scaffold(
      appBar: const TopBar(title: 'Delete account'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconTile(PhosphorIcons.warning(PhosphorIconsStyle.fill), tone: Tone.red, size: 56, radius: 16),
          ),
          const Gap(Space.s4),
          Text('We are sad to see you go', style: context.ty.h1),
          const Gap(Space.s4),
          Text('Deleting your account is permanent. This will remove:', style: context.ty.body.col(c.textMuted)),
          const Gap(Space.s4),
          for (final t in const [
            'Your profile and login',
            'Your test history and scores',
            'Your AI chat history',
            'Any Premium time you have left (no refund)',
          ]) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), size: 20, color: c.error),
                const Gap(Space.s3),
                Expanded(
                  child: Text(t, style: context.ty.body.copyWith(fontSize: 14, height: 20 / 14)),
                ),
              ],
            ),
            const Gap(Space.s3),
          ],
          const Gap(Space.s1),
          const InfoBanner(child: Text('Payment records are kept for 6 years because the law requires it. They are not linked to your profile.')),
          const Gap(Space.s4),
          Field(
            label: 'Type DELETE to confirm',
            hint: 'DELETE',
            controller: _ctl,
            caps: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            error: _error,
          ),
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Btn('Delete my account', kind: BtnKind.danger, block: true, loading: _busy, onPressed: ready ? _delete : null),
            const Gap(Space.s2),
            Btn('Cancel', kind: BtnKind.ghost, onPressed: _busy ? null : () => context.pop()),
          ],
        ),
      ),
    );
  }
}
