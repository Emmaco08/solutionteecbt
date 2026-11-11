import 'dart:async';

import 'package:flutter/material.dart';
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

// Request a tutor (C12, D-149): the student asks, the SolutionTee team replies in this chat (and by email), the
// student buys a tutor plan, and the assigned tutor's WhatsApp / phone show only while the plan is active. All of it
// comes from the server (tutor_overview); prices are never set in the app.

final tutorProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'tutor:$uid', (s) => s.rpc('tutor_overview'), (j) => Map<String, dynamic>.from((j as Map?) ?? const {}));
});

const tutorLevels = [('jamb', 'JAMB'), ('waec', 'WAEC'), ('neco', 'NECO'), ('post_utme', 'Post-UTME'), ('other', 'Other')];

/// Open request = new, replied or matched (one at a time).
bool tutorOpen(Map<String, dynamic>? req) => req != null && req['status'] != 'closed';

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

/// Study card: the way in.
class TutorCard extends ConsumerWidget {
  const TutorCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final req = ref.watch(tutorProvider).value?['request'] as Map?;
    final open = tutorOpen(req == null ? null : Map<String, dynamic>.from(req));
    return AppCard(
      onTap: () => context.push('/tutor'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill), tone: Tone.green, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(open ? 'My tutor request' : 'Request a tutor', style: context.ty.body.bold),
                const Gap(2),
                Text(
                  open ? 'See replies from SolutionTee and your tutor plan.' : 'Get a real teacher for the subjects you find hard.',
                  style: context.ty.cap.col(c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
  Timer? _poll;
  bool _newForm = false;

  @override
  void initState() {
    super.initState();
    // New replies show without leaving the screen (every 20 s, only while it is open; data-light).
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && tutorOpen(ref.read(tutorProvider).value?['request'] as Map<String, dynamic>?)) ref.invalidate(tutorProvider);
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
    return Scaffold(
      appBar: TopBar(title: 'Request a tutor'),
      body: asyncView(v, onRetry: _refresh, (d) {
        final req = d['request'] == null ? null : Map<String, dynamic>.from(d['request'] as Map);
        final showForm = req == null || (req['status'] == 'closed' && _newForm);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: showForm
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
                  children: [
                    const _Intro(),
                    const Gap(Space.s5),
                    TutorRequestForm(onSent: () => setState(() => _newForm = false)),
                  ],
                )
              : _Conversation(data: d, request: req, onNew: () => setState(() => _newForm = true)),
        );
      }),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget step(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Row(
        children: [
          IconTile(i, tone: Tone.blue, size: 32),
          const Gap(Space.s3),
          Expanded(child: Text(t, style: context.ty.sm)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Get help from a real teacher', style: context.ty.h2),
        const Gap(Space.s1),
        Text('Tell us what you need. We reply here and by email, usually within a day.', style: context.ty.sm.col(c.textMuted)),
        const Gap(Space.s3),
        step(PhosphorIcons.notePencil(PhosphorIconsStyle.fill), 'Send your request: subject, exam and what you want to improve.'),
        step(PhosphorIcons.chatsCircle(PhosphorIconsStyle.fill), 'Chat with the SolutionTee team and pick a tutor plan.'),
        step(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), 'Meet your tutor on WhatsApp or by phone while your plan is on.'),
      ],
    );
  }
}

/// Subject, exam, goals and free times.
class TutorRequestForm extends ConsumerStatefulWidget {
  const TutorRequestForm({super.key, this.onSent});
  final VoidCallback? onSent;
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
        widget.onSent?.call();
        toast(context, 'Request sent. We will reply soon.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      } else {
        setState(
          () => _error = switch ('${r['error']}') {
            'open' => 'You already have an open request. Reply in that chat.',
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
    final c = context.c;
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
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
            for (final s in subjects) DropdownMenuItem<int?>(value: (s['id'] as num).toInt(), child: Text('${s['name']}')),
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
        Btn('Send request', block: true, loading: _busy, onPressed: _busy ? null : _send),
        const Gap(Space.s2),
        Text(
          'Keep your chats safe: never share passwords or pay anyone outside SolutionTee.',
          style: context.ty.cap.col(c.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Conversation extends ConsumerStatefulWidget {
  const _Conversation({required this.data, required this.request, required this.onNew});
  final Map<String, dynamic> data;
  final Map<String, dynamic>? request;
  final VoidCallback onNew;
  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _paying;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _say(String m, [IconData? i]) => toast(context, m, icon: i ?? PhosphorIcons.info(PhosphorIconsStyle.fill));

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = Map<String, dynamic>.from(
        await Supabase.instance.client
                .rpc('tutor_message_send', params: {'p_request': widget.request!['id'], 'p_body': body})
                .timeout(const Duration(seconds: 15))
            as Map,
      );
      if (!mounted) return;
      if (r['ok'] == true) {
        if (preset == null) _text.clear();
        ref.invalidate(tutorProvider);
      } else {
        _say(r['error'] == 'too_many' ? 'You have sent many messages. Please wait a little.' : 'Could not send. Try again.');
      }
    } catch (_) {
      if (mounted) _say('Could not reach SolutionTee. Check your internet and try again.', PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _buy(Map<String, dynamic> plan) async {
    if (_paying != null) return;
    // The Play Store build has no Paystack: the student asks in the chat and the team helps (D-149).
    if (!usesPaystackNow(ref)) return _send('I would like the ${plan['name']} plan. How do I pay?');
    setState(() => _paying = '${plan['id']}');
    try {
      final r = await payForItem(context, ref, itemRef: '${plan['id']}', title: 'Tutor plan: ${plan['name']}', priceKobo: (plan['price_kobo'] as num).toInt());
      if (!mounted) return;
      switch (r) {
        case PaySuccess():
          ref.invalidate(tutorProvider);
          _say('Your tutor plan is on!', PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
        case PayFailed(:final message):
          _say(message, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        case PayCancelled():
          _say('Payment cancelled. You were not charged.');
        case PayPending():
          _say('We are waiting for Paystack. Your plan starts as soon as the payment is confirmed.', PhosphorIcons.clock(PhosphorIconsStyle.fill));
        default:
          break;
      }
    } finally {
      if (mounted) setState(() => _paying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.data;
    final req = widget.request!;
    final closed = req['status'] == 'closed';
    final msgs = [for (final m in (d['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    final plans = [for (final p in (d['plans'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    final sub = d['subscription'] == null ? null : Map<String, dynamic>.from(d['subscription'] as Map);
    final tutor = d['tutor'] == null ? null : Map<String, dynamic>.from(d['tutor'] as Map);
    final level = tutorLevels.where((l) => l.$1 == req['level']).firstOrNull?.$2 ?? 'Other';
    final subject = (ref.watch(subjectsProvider).value ?? const []).where((s) => s['id'] == req['subject_id']).firstOrNull?['name'];

    return Column(
      children: [
        Expanded(
          child: ListView(
            reverse: false,
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s4),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('$level${subject != null ? ' · $subject' : ''}', style: context.ty.body.bold)),
                        Pill(
                          switch ('${req['status']}') {
                            'new' => 'Waiting for reply',
                            'replied' => 'Replied',
                            'matched' => 'Tutor assigned',
                            _ => 'Closed',
                          },
                          kind: switch ('${req['status']}') {
                            'new' => BadgeKind.warning,
                            'matched' => BadgeKind.success,
                            'closed' => BadgeKind.neutral,
                            _ => BadgeKind.soft,
                          },
                        ),
                      ],
                    ),
                    const Gap(Space.s1),
                    Text('${req['goals']}', style: context.ty.sm.col(c.textMuted), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (tutor != null) ...[const Gap(Space.s3), _TutorContact(tutor: tutor)],
              const Gap(Space.s3),
              if (sub != null)
                InfoBanner(
                  kind: BannerKind.ok,
                  child: Text(
                    'Your ${sub['plan']} plan is on until ${tutorDate(sub['ends_at'])}.${tutor == null ? ' We will assign your tutor here soon.' : ''}',
                    style: context.ty.sm,
                  ),
                )
              else if (plans.isNotEmpty && !closed) ...[
                const SectTitle('Tutor plans'),
                for (final p in plans) ...[
                  _PlanTile(plan: p, busy: _paying == '${p['id']}', onBuy: () => _buy(p), playBuild: !usesPaystackNow(ref)),
                  const Gap(Space.s2),
                ],
              ],
              const Gap(Space.s4),
              const SectTitle('Messages'),
              for (final m in msgs) _Bubble(m: m),
              if (closed) ...[
                const Gap(Space.s4),
                Text('This request is closed.', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                const Gap(Space.s2),
                Btn('Ask for a tutor again', kind: BtnKind.secondary, block: true, onPressed: widget.onNew),
              ],
            ],
          ),
        ),
        if (!closed)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s2, Space.s2),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.ty.body,
                      decoration: const InputDecoration(hintText: 'Write a message…', counterText: ''),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Gap(Space.s2),
                  IconBtn(
                    PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                    label: 'Send message',
                    onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final staff = m['from_staff'] == true;
    final t = DateTime.tryParse('${m['at']}')?.toLocal();
    final time = t == null ? '' : '${tutorDate(m['at'])}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: staff ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: Space.s2),
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
        decoration: BoxDecoration(
          color: staff ? c.surface : c.primary,
          border: staff ? Border.all(color: c.border) : null,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (staff) Text('SolutionTee', style: context.ty.cap.bold.col(c.secondary)),
            Text('${m['body']}', style: context.ty.sm.col(staff ? c.text : c.onPrimary)),
            const Gap(2),
            Text(time, style: context.ty.cap.col(staff ? c.textSubtle : c.onPrimary.withValues(alpha: .7))),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.busy, required this.onBuy, required this.playBuild});
  final Map<String, dynamic> plan;
  final bool busy, playBuild;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = (plan['days'] as num?)?.toInt() ?? 30;
    final sessions = (plan['sessions'] as num?)?.toInt();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${plan['name']}', style: context.ty.body.bold)),
              Text(naira((plan['price_kobo'] as num).toInt()), style: context.ty.body.bold.tnum),
            ],
          ),
          Text('$days days${sessions != null ? ' · $sessions lessons' : ''}', style: context.ty.cap.col(c.textMuted)),
          if ('${plan['description'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s1), Text('${plan['description']}', style: context.ty.sm)],
          const Gap(Space.s3),
          Btn(playBuild ? 'Ask about this plan' : 'Choose this plan', sm: true, loading: busy, onPressed: busy ? null : onBuy),
        ],
      ),
    );
  }
}

class _TutorContact extends StatelessWidget {
  const _TutorContact({required this.tutor});
  final Map<String, dynamic> tutor;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wa = '${tutor['whatsapp'] ?? ''}', phone = '${tutor['phone'] ?? ''}';
    Future<void> open(Uri u) async {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && context.mounted) toast(context, 'Could not open it on this phone.');
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(PhosphorIcons.userCircle(PhosphorIconsStyle.fill), tone: Tone.green, size: 44),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your tutor: ${tutor['name']}', style: context.ty.body.bold),
                    if ('${tutor['subjects'] ?? ''}'.isNotEmpty) Text('${tutor['subjects']}', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if ('${tutor['bio'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s2), Text('${tutor['bio']}', style: context.ty.sm)],
          const Gap(Space.s3),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              if (wa.isNotEmpty)
                Btn('WhatsApp', sm: true, leading: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), onPressed: () => open(whatsappUri(wa))),
              if (phone.isNotEmpty)
                Btn(
                  'Call',
                  sm: true,
                  kind: BtnKind.secondary,
                  leading: PhosphorIcons.phone(PhosphorIconsStyle.fill),
                  onPressed: () => open(Uri.parse('tel:$phone')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
