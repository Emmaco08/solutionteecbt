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
import '../../widgets/states.dart';
import '../premium/item_pay.dart';
import '../premium/payments.dart';
import '../premium/paywall.dart';
import 'tutor_chat.dart';

// Request a tutor, v2 (D-152): request → choose a plan (or a custom price) → pay (Paystack in the app, Google Play in
// the Play build, or the website as the admin chooses) → "a tutor within 24 hours" → chat with the tutor like WhatsApp.

final tutorProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'tutor:$uid', (s) => s.rpc('tutor_overview'), (j) => Map<String, dynamic>.from((j as Map?) ?? const {}));
});

const tutorLevels = [('jamb', 'JAMB'), ('waec', 'WAEC'), ('neco', 'NECO'), ('post_utme', 'Post-UTME'), ('other', 'Other')];

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

/// WhatsApp link for a Nigerian number: 0801… → 234801…
Uri whatsappUri(String number) {
  var n = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '234${n.substring(1)}';
  return Uri.parse('https://wa.me/$n');
}

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

class _TutorScreenState extends ConsumerState<TutorScreen> {
  bool _support = false; // chat with the SolutionTee team before a tutor is assigned
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // While waiting for a tutor, check now and then so the chat opens by itself when one is assigned.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      final req = ref.read(tutorProvider).value?['request'] as Map?;
      if (mounted && req?['status'] == 'paid') ref.invalidate(tutorProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
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

    if (d != null && req != null && (stage == TutorStage.chat || stage == TutorStage.ended || _support)) {
      return TutorChatView(
        key: ValueKey('chat-${req['id']}'),
        requestId: '${req['id']}',
        initial: msgs,
        tutor: stage == TutorStage.chat || stage == TutorStage.ended ? tutor : null,
        readOnly: stage == TutorStage.ended ? 'Your tutor plan has ended. Renew it to keep chatting.' : null,
        footer: stage == TutorStage.ended ? _RenewBar(onTap: () => _openPlans(context, d)) : null,
        onBack: _support ? () => setState(() => _support = false) : null,
      );
    }
    return Scaffold(
      appBar: TopBar(title: stage == TutorStage.waiting ? 'My tutor' : 'Request a tutor'),
      body: asyncView(v, onRetry: _refresh, (d) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: switch (stage) {
            TutorStage.request => ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
              children: const [_Hero(), Gap(Space.s5), TutorRequestForm()],
            ),
            TutorStage.waiting => _Waiting(data: d, onChat: () => setState(() => _support = true)),
            _ => _Plans(data: d, onChat: () => setState(() => _support = true)),
          },
        );
      }),
    );
  }

  void _openPlans(BuildContext context, Map<String, dynamic> d) => showSheet<void>(context, scroll: true, builder: (ctx) => _PlanList(data: d, inSheet: true));
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

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget step(int i, IconData icon, String t, String s) {
      final w = Padding(
        padding: const EdgeInsets.only(top: Space.s3),
        child: Row(
          children: [
            IconTile(icon, tone: Tone.blue, size: 40),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: context.ty.sm.bold),
                  Text(s, style: context.ty.cap.col(c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
      return rm ? w : w.animate().fadeIn(delay: (120 + 80 * i).ms, duration: Motion.base).slideX(begin: .08, end: 0, curve: Curves.easeOut);
    }

    final head = Container(
      padding: const EdgeInsets.all(Space.s5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, c.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Learn with a real teacher', style: context.ty.h2.col(Colors.white)),
                const Gap(Space.s1),
                Text('Chat, voice notes, photos of your questions and live calls.', style: context.ty.sm.col(Colors.white.withValues(alpha: .85))),
              ],
            ),
          ),
          const Gap(Space.s3),
          Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 56, color: c.accent),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rm ? head : head.animate().fadeIn(duration: Motion.base).scaleXY(begin: .96, end: 1, curve: Curves.easeOut),
        step(0, PhosphorIcons.notePencil(PhosphorIconsStyle.fill), 'Tell us what you need', 'Subject, exam and what you want to improve.'),
        step(1, PhosphorIcons.creditCard(PhosphorIconsStyle.fill), 'Choose a plan and pay', 'Or ask for a custom plan and we send a price.'),
        step(2, PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill), 'Meet your tutor within 24 hours', 'Chat like WhatsApp and join calls from the chat.'),
      ],
    );
  }
}

/// Subject (from the student's combination first), exam, goals and free times.
class TutorRequestForm extends ConsumerStatefulWidget {
  const TutorRequestForm({super.key});
  @override
  ConsumerState<TutorRequestForm> createState() => _TutorRequestFormState();
}

class _TutorRequestFormState extends ConsumerState<TutorRequestForm> {
  final _goals = TextEditingController();
  final _times = TextEditingController();
  int? _subject;
  String _level = 'jamb';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _goals.dispose();
    _times.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_goals.text.trim().length < 5) return setState(() => _error = 'Tell us a little about what you need (at least 5 letters).');
    setState(() => (_busy = true, _error = null));
    try {
      final r = Map<String, dynamic>.from(
        await Supabase.instance.client
                .rpc('tutor_request_create', params: {'p_subject': _subject, 'p_level': _level, 'p_goals': _goals.text.trim(), 'p_times': _times.text.trim()})
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

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    final mine = {for (final s in (ref.watch(profileProvider).value?['jamb_subjects'] as List? ?? const [])) '$s'.toLowerCase()};
    final sorted = [...subjects]
      ..sort(
        (a, b) => (mine.contains('${b['code']}'.toLowerCase()) || mine.contains('${b['name']}'.toLowerCase()) ? 1 : 0).compareTo(
          mine.contains('${a['code']}'.toLowerCase()) || mine.contains('${a['name']}'.toLowerCase()) ? 1 : 0,
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Exam', style: context.ty.sm.bold),
        const Gap(Space.s2),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [for (final (k, label) in tutorLevels) AppChip(label, on: _level == k, onTap: () => setState(() => _level = k))],
        ),
        const Gap(Space.s4),
        Text('Subject', style: context.ty.sm.bold),
        const Gap(Space.s2),
        DropdownButtonFormField<int?>(
          initialValue: _subject,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Choose a subject'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Several subjects / not sure')),
            for (final s in sorted) DropdownMenuItem<int?>(value: (s['id'] as num).toInt(), child: Text('${s['name']}')),
          ],
          onChanged: (v) => setState(() => _subject = v),
        ),
        const Gap(Space.s4),
        Text('What do you want help with?', style: context.ty.sm.bold),
        const Gap(Space.s2),
        TextField(
          controller: _goals,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          style: context.ty.body,
          decoration: const InputDecoration(hintText: 'For example: I want to understand graphs in Physics and score 250+ in JAMB.'),
        ),
        const Gap(Space.s2),
        Text('When are you free? (optional)', style: context.ty.sm.bold),
        const Gap(Space.s2),
        TextField(
          controller: _times,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          style: context.ty.body,
          decoration: const InputDecoration(hintText: 'Weekday evenings, Saturday morning', counterText: ''),
        ),
        if (_error != null) ...[const Gap(Space.s3), ErrText(_error!)],
        const Gap(Space.s5),
        Btn('See tutor plans', block: true, loading: _busy, icon: PhosphorIcons.arrowRight(), onPressed: _busy ? null : _send),
      ],
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data, required this.onChat});
  final Map<String, dynamic> data;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
    children: [
      _PlanList(data: data),
      const Gap(Space.s4),
      Center(
        child: TextButton.icon(onPressed: onChat, icon: Icon(PhosphorIcons.chatsCircle(), size: 18), label: const Text('Questions? Chat with SolutionTee')),
      ),
    ],
  );
}

/// The plans, the custom price (when sent) and "Ask for a custom plan".
class _PlanList extends ConsumerStatefulWidget {
  const _PlanList({required this.data, this.inSheet = false});
  final Map<String, dynamic> data;
  final bool inSheet;
  @override
  ConsumerState<_PlanList> createState() => _PlanListState();
}

class _PlanListState extends ConsumerState<_PlanList> {
  String? _paying;
  final _custom = TextEditingController();
  bool _asking = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _say(String m, [IconData? i]) => toast(context, m, icon: i ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _pay({required String ref_, required String title, required int price, String? playId}) async {
    if (_paying != null) return;
    setState(() => _paying = ref_);
    try {
      PayResult r;
      if (usesPaystackNow(ref)) {
        r = await payForItem(context, ref, itemRef: ref_, title: title, priceKobo: price);
      } else {
        final s = ref.read(paySettingsProvider);
        if (playId != null && playId.isNotEmpty && s.playGoogle) {
          r = await ref.read(paymentProvider(false)).buy({'play_product_id': playId});
        } else {
          // No Google Play product (custom prices, or the admin offers the website): pay on cbt.solutiontee.com/tutor.
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
          if (widget.inSheet) Navigator.of(context).maybePop();
          _say('Payment received! Your tutor is coming within 24 hours.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
        case PayFailed(:final message):
          _say(message, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        case PayCancelled():
          _say('Payment cancelled. You were not charged.');
        case PayPending():
          _say('We are waiting for the payment to be confirmed. This page updates by itself.', PhosphorIcons.clock(PhosphorIconsStyle.fill));
          ref.invalidate(tutorProvider);
        default:
          break;
      }
    } finally {
      if (mounted) setState(() => _paying = null);
    }
  }

  Future<void> _askCustom(String requestId) async {
    if (_custom.text.trim().length < 5) return _say('Tell us a little more about what you need.');
    setState(() => _asking = true);
    try {
      final r = await Supabase.instance.client.rpc('tutor_custom_request', params: {'p_request': requestId, 'p_note': _custom.text.trim()});
      if (!mounted) return;
      if ((r as Map?)?['ok'] == true) {
        _custom.clear();
        ref.invalidate(tutorProvider);
        _say('Sent. We will send you a price, usually within a day.', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      } else {
        _say('Could not send. Try again.');
      }
    } catch (_) {
      if (mounted) _say('Could not reach SolutionTee. Check your internet.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final req = Map<String, dynamic>.from(widget.data['request'] as Map? ?? const {});
    final plans = [for (final p in (widget.data['plans'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    final customPrice = (req['custom_price_kobo'] as num?)?.toInt();
    final best = plans.length >= 3 ? 1 : -1;
    Widget anim(Widget w, int i) => rm ? w : w.animate().fadeIn(delay: (70 * i).ms, duration: Motion.base).slideY(begin: .1, end: 0, curve: Curves.easeOut);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(req['status'] == 'ended' ? 'Renew your tutor plan' : 'Choose your tutor plan', style: context.ty.h2),
        const Gap(Space.s1),
        Text('A tutor is assigned within 24 hours of payment.', style: context.ty.sm.col(c.textMuted)),
        const Gap(Space.s4),
        if (customPrice != null)
          anim(
            _PlanCard(
              title: 'Your custom plan',
              price: customPrice,
              line: '${req['custom_days'] ?? 30} days',
              desc: '${req['custom_note'] ?? ''}',
              highlight: true,
              badge: 'For you',
              busy: _paying == '${req['id']}',
              onPay: () => _pay(ref_: '${req['id']}', title: 'Custom tutor plan', price: customPrice),
            ),
            0,
          ),
        for (final (i, p) in plans.indexed)
          anim(
            _PlanCard(
              title: '${p['name']}',
              price: (p['price_kobo'] as num).toInt(),
              line: '${p['days']} days${p['sessions'] != null ? ' · ${p['sessions']} lessons' : ''}',
              desc: '${p['description'] ?? ''}',
              highlight: i == best,
              badge: i == best ? 'Most popular' : null,
              busy: _paying == '${p['id']}',
              onPay: () =>
                  _pay(ref_: '${p['id']}', title: 'Tutor plan: ${p['name']}', price: (p['price_kobo'] as num).toInt(), playId: p['play_product_id'] as String?),
            ),
            i + 1,
          ),
        if (req['id'] != null)
          anim(
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconTile(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), tone: Tone.gold, size: 36),
                      const Gap(Space.s3),
                      Expanded(child: Text('Custom plan', style: context.ty.body.bold)),
                    ],
                  ),
                  const Gap(Space.s2),
                  Text(
                    req['custom_note'] != null && customPrice == null
                        ? 'We got your request: "${req['custom_note']}". We will send you a price soon.'
                        : 'Need something different (more lessons, weekends, a group)? Tell us and we send you a price.',
                    style: context.ty.sm.col(c.textMuted),
                  ),
                  if (req['custom_note'] == null || customPrice != null) ...[
                    const Gap(Space.s3),
                    TextField(
                      controller: _custom,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.ty.body,
                      decoration: const InputDecoration(hintText: 'I need weekend classes for 2 months', counterText: ''),
                    ),
                    const Gap(Space.s3),
                    Btn('Ask for a price', kind: BtnKind.outline, loading: _asking, onPressed: _asking ? null : () => _askCustom('${req['id']}')),
                  ],
                ],
              ),
            ),
            plans.length + 1,
          ),
        const Gap(Space.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 14, color: c.textSubtle),
            const Gap(Space.s1),
            Text(usesPaystack(ref) ? 'Safe payment with Paystack' : 'Safe payment with Google Play or our website', style: context.ty.cap.col(c.textSubtle)),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.line,
    required this.desc,
    required this.busy,
    required this.onPay,
    this.highlight = false,
    this.badge,
  });
  final String title, line, desc;
  final int price;
  final bool busy, highlight;
  final String? badge;
  final VoidCallback onPay;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: highlight ? c.accent : c.border, width: highlight ? 2 : 1),
          color: c.surface,
          boxShadow: context.shadow(highlight ? 2 : 1),
        ),
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.ty.body.bold)),
                if (badge != null) Pill(badge!, kind: BadgeKind.gold),
              ],
            ),
            const Gap(Space.s1),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: Space.s2,
              children: [
                Text(naira(price), style: context.ty.h1.tnum),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: context.ty.sm.col(c.textMuted)),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[const Gap(Space.s1), Text(desc, style: context.ty.sm)],
            const Gap(Space.s3),
            Btn(
              busy ? 'Opening payment…' : 'Choose this plan',
              block: true,
              kind: highlight ? BtnKind.accent : BtnKind.primary,
              loading: busy,
              onPressed: busy ? null : onPay,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paid: a calm animated "we are finding your tutor" screen with what happens next.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.data, required this.onChat});
  final Map<String, dynamic> data;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final sub = data['subscription'] as Map?;
    Widget ring(double size, int delay) {
      final w = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.secondary.withValues(alpha: .35), width: 2),
        ),
      );
      return rm
          ? w
          : w
                .animate(onPlay: (a) => a.repeat())
                .scaleXY(begin: .6, end: 1.15, delay: delay.ms, duration: 2400.ms, curve: Curves.easeOut)
                .fadeOut(duration: 2400.ms);
    }

    Widget step(String t, String s, {required bool done, bool active = false}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? c.success
                  : active
                  ? c.secondary
                  : c.surfaceSunken,
            ),
            child: Icon(
              done ? PhosphorIcons.check(PhosphorIconsStyle.bold) : PhosphorIcons.dotOutline(PhosphorIconsStyle.fill),
              size: 16,
              color: done || active ? Colors.white : c.textSubtle,
            ),
          ),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: context.ty.sm.bold),
                Text(s, style: context.ty.cap.col(c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s6, Space.s5, Space.s8),
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ring(180, 0),
              ring(180, 800),
              ring(180, 1600),
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [c.secondary, c.primary]),
                  boxShadow: context.shadow(3),
                ),
                child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 48, color: c.accent),
              ),
            ],
          ),
        ),
        const Gap(Space.s4),
        Text('Finding your tutor', style: context.ty.h1, textAlign: TextAlign.center),
        const Gap(Space.s1),
        Text(
          'Payment received. A tutor will be assigned to you within 24 hours. We will notify you and the chat opens here.',
          style: context.ty.body.col(c.textMuted),
          textAlign: TextAlign.center,
        ),
        const Gap(Space.s6),
        AppCard(
          child: Column(
            children: [
              step('Payment received', sub != null ? '${sub['plan']} plan until ${tutorDate(sub['ends_at'])}' : 'Thank you!', done: true),
              step('Matching you with a tutor', 'We pick a tutor for your subject and goals.', done: false, active: true),
              step('Start learning', 'Chat, send photos and voice notes, join calls.', done: false),
            ],
          ),
        ),
        const Gap(Space.s4),
        Btn('Chat with SolutionTee', kind: BtnKind.outline, block: true, leading: PhosphorIcons.chatsCircle(), onPressed: onChat),
      ],
    );
  }
}
