import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device.dart';
import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../compete/compete_data.dart' show challengeError, nairaWhole;
import '../profile/profile_screens.dart' show signOutAndWipe;

/// Referrals, one account per phone, bans (milestone 4E3, D-031, D-032, D-078). The server decides who counts,
/// the discount and the rewards; the phone only shows them.

final myReferralsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final j = await ref.read(supabaseProvider).rpc('my_referrals').timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(j as Map);
});

/// What the server says about this account on this phone (set by the shell after `device_register`).
final accountStatusProvider = NotifierProvider<AccountStatus, Map<String, dynamic>?>(AccountStatus.new);

class AccountStatus extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void set(Map<String, dynamic>? s) => state = s;
}

/// The WhatsApp / share message with the student's code.
String inviteText(String code) =>
    'Join me on SolutionTee CBT to practise JAMB, WAEC and NECO past questions. Use my code $code when you sign up. '
    'Get the app: https://cbt.solutiontee.com';

int _i(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;

/// Me → Invite friends (prototype `referral`): code, share, discount meter, cash progress, friends.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(myReferralsProvider);
    return Scaffold(
      appBar: const TopBar(title: 'Invite friends'),
      body: asyncView(
        v,
        (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myReferralsProvider),
          child: _InviteBody(d: d),
        ),
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: const [
            Skeleton(height: 190, radius: Radii.lg),
            Gap(Space.s3),
            Skeleton(height: 120, radius: Radii.lg),
            Gap(Space.s3),
            Skeleton(height: 160, radius: Radii.lg),
          ],
        ),
        onRetry: () => ref.invalidate(myReferralsProvider),
      ),
    );
  }
}

class _InviteBody extends ConsumerWidget {
  const _InviteBody({required this.d});
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    if (d['enabled'] == false) {
      return ListView(
        children: [
          const Gap(Space.s8),
          StateBlock(icon: PhosphorIcons.gift(PhosphorIconsStyle.fill), tone: Tone.gold, title: 'Invites are paused', text: 'Check back soon.'),
        ],
      );
    }
    final code = '${d['code']}';
    final per = _i(d['pct_per_friend'], 10), maxPct = _i(d['max_pct'], 100), pct = _i(d['discount_pct']);
    final counted = _i(d['counted']),
        every = cashPrizesOn ? _i(d['cash_every']) : 0,
        cash = cashPrizesOn ? _i(d['cash_naira']) : 0,
        cap = _i(d['monthly_cap'], 20);
    final friends = rows(d['friends']), rewards = rows(d['rewards']);
    final waiting = friends.where((f) => f['status'] == 'pending').length;
    final premiumRule = d['count_on'] == 'premium';
    final sections = <Widget>[
      Container(
        padding: const EdgeInsets.all(Space.s5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get Premium cheaper', style: context.ty.h2.col(Colors.white)),
            const Gap(Space.s1),
            Text(
              '$per% off Premium for every friend who joins with your code${maxPct >= 100 ? ', up to free Premium' : ', up to $maxPct%'}.',
              style: context.ty.sm.col(const Color(0xFFDCE4F2)),
            ),
            const Gap(Space.s4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your code', style: context.ty.cap.col(const Color(0xFFDCE4F2))),
                        SelectableText(code, style: context.ty.h2.tnum.col(Palette.gold500)),
                      ],
                    ),
                  ),
                  IconBtn(
                    PhosphorIcons.copy(),
                    label: 'Copy code',
                    color: Colors.white,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) toast(context, 'Code copied', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
                    },
                  ),
                ],
              ),
            ),
            const Gap(Space.s3),
            Btn(
              'Share on WhatsApp',
              kind: BtnKind.accent,
              block: true,
              leading: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
              onPressed: () async {
                final ok = await launchUrl(
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent(inviteText(code))}'),
                  mode: LaunchMode.externalApplication,
                ).catchError((_) => false);
                if (!ok) {
                  await Clipboard.setData(ClipboardData(text: inviteText(code)));
                  if (context.mounted) toast(context, 'Message copied. Paste it in any chat.', icon: PhosphorIcons.copy());
                }
              },
            ),
          ],
        ),
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Your discount', style: context.ty.body.bold)),
                Text('$pct%', style: context.ty.h2.tnum.col(pct > 0 ? c.success : c.text)),
              ],
            ),
            const Gap(Space.s2),
            ProgressBar(maxPct == 0 ? 0 : pct / maxPct, color: c.success),
            const Gap(Space.s2),
            Text(
              pct > 0
                  ? 'Used on your next Premium payment (website or this app with Paystack). Paying uses those friends.'
                  : 'Invite friends to start your discount.',
              style: context.ty.cap.col(c.textMuted),
            ),
            if (pct > 0) ...[
              const Gap(Space.s3),
              Btn('Get Premium with my discount', kind: BtnKind.tonal, block: true, onPressed: () => context.push('/checkout?plan=three_months')),
            ],
          ],
        ),
      ),
      if (every > 0 && cash > 0)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(PhosphorIcons.money(PhosphorIconsStyle.fill), tone: Tone.gold, size: 36, radius: 10, iconSize: 18),
                  const Gap(Space.s3),
                  Expanded(child: Text('${nairaWhole(cash)} cash every $every friends', style: context.ty.sm.bold)),
                ],
              ),
              const Gap(Space.s3),
              ProgressBar((counted % every) / every, color: Palette.gold500),
              const Gap(Space.s2),
              Text('${counted % every} of $every · ${every - counted % every} more to go', style: context.ty.cap.tnum.col(c.textMuted)),
              for (final w in rewards) ...[const Gap(Space.s3), _Reward(w: w)],
            ],
          ),
        ),
      if (d['can_enter_code'] == true) const _EnterCode(),
      if (d['my_referrer'] != null) Text('You joined with ${d['my_referrer']}\'s code.', style: context.ty.cap.col(c.textMuted), textAlign: TextAlign.center),
      SectTitle('Your friends${friends.isEmpty ? '' : ' (${friends.length})'}'),
      if (friends.isEmpty)
        Text('Nobody has joined with your code yet.', style: context.ty.sm.col(c.textMuted))
      else
        ListCard(
          children: [
            for (final f in friends)
              Padding(
                padding: const EdgeInsets.all(Space.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${f['name']}', style: context.ty.sm.bold),
                          if ((f['reason'] ?? '').toString().isNotEmpty) Text('${f['reason']}', style: context.ty.cap.col(c.textMuted)),
                          if (f['used'] == true) Text('Used for a discount', style: context.ty.cap.col(c.textMuted)),
                        ],
                      ),
                    ),
                    Pill(
                      f['status'] == 'counted'
                          ? 'Counted'
                          : f['status'] == 'blocked'
                          ? 'Not counted'
                          : 'Waiting',
                      kind: f['status'] == 'counted'
                          ? BadgeKind.success
                          : f['status'] == 'blocked'
                          ? BadgeKind.error
                          : BadgeKind.neutral,
                    ),
                  ],
                ),
              ),
          ],
        ),
      if (waiting > 0) Text('$waiting waiting. They count when they finish the step below.', style: context.ty.cap.col(c.textMuted)),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: context.ty.sm.bold),
            const Gap(Space.s2),
            for (final t in [
              'Your friend signs up with your code.',
              premiumRule
                  ? 'They count when they verify their email and buy Premium.'
                  : 'They count when they verify their email and finish one practice test on their own phone.',
              'Each friend gives you $per% off Premium. Up to $cap friends count each month.',
              if (every > 0 && cash > 0) 'Every $every friends in total: ${nairaWhole(cash)} cash, paid after a check.',
              'Friends on your phone, or fake accounts, do not count and can get accounts banned.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: c.textSubtle),
                    ),
                    const Gap(Space.s2),
                    Expanded(child: Text(t, style: context.ty.cap.col(c.textMuted))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
      children: [
        for (var i = 0; i < sections.length; i++) ...[if (i > 0) const Gap(Space.s3), sections[i]],
      ],
    );
  }
}

/// A cash reward: send bank details once (never PIN, card or password).
class _Reward extends ConsumerStatefulWidget {
  const _Reward({required this.w});
  final Map<String, dynamic> w;
  @override
  ConsumerState<_Reward> createState() => _RewardState();
}

class _RewardState extends ConsumerState<_Reward> {
  final _bank = TextEditingController(), _num = TextEditingController(), _name = TextEditingController();
  bool _open = false, _busy = false;
  String? _err;

  @override
  void dispose() {
    _bank.dispose();
    _num.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'referral_claim',
            params: {'p_reward': widget.w['id'], 'p_bank': _bank.text.trim(), 'p_account_number': _num.text.trim(), 'p_account_name': _name.text.trim()},
          );
      ref.invalidate(myReferralsProvider);
      if (mounted) toast(context, 'Sent. We pay within 3 working days after a check.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    } on PostgrestException catch (e) {
      setState(() => _err = challengeError(e));
    } catch (_) {
      setState(() => _err = 'Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w, c = context.c;
    final status = '${w['status']}';
    final label = switch (status) {
      'paid' => 'Paid',
      'claimed' => 'We have your details',
      'cancelled' => 'Cancelled',
      _ => 'Ready to claim',
    };
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${nairaWhole(_i(w['amount']))} · ${w['milestone']} friends', style: context.ty.sm.bold)),
              Pill(label, kind: status == 'paid' ? BadgeKind.success : (status == 'due' ? BadgeKind.gold : BadgeKind.neutral)),
            ],
          ),
          if (status == 'due' && !_open) ...[
            const Gap(Space.s2),
            Btn('Send my account details', kind: BtnKind.accent, sm: true, onPressed: () => setState(() => _open = true)),
          ],
          if (status == 'due' && _open) ...[
            const Gap(Space.s3),
            TextField(
              controller: _bank,
              decoration: const InputDecoration(labelText: 'Bank (e.g. GTBank, OPay)'),
            ),
            const Gap(Space.s2),
            TextField(
              controller: _num,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '10-digit account number'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Account name'),
            ),
            const Gap(Space.s2),
            Text('We never ask for your PIN, card or password.', style: context.ty.cap.col(c.textMuted)),
            if (_err != null) ...[const Gap(Space.s2), Text(_err!, style: context.ty.cap.col(c.error))],
            const Gap(Space.s2),
            Btn('Send', block: true, loading: _busy, onPressed: _busy ? null : _send),
          ],
        ],
      ),
    );
  }
}

/// Forgot the code at sign-up: add it in the first 7 days.
class _EnterCode extends ConsumerStatefulWidget {
  const _EnterCode();
  @override
  ConsumerState<_EnterCode> createState() => _EnterCodeState();
}

class _EnterCodeState extends ConsumerState<_EnterCode> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2,20}-[A-Z0-9]{4}$').hasMatch(code)) return setState(() => _err = 'That code does not look right. It looks like TOLU-7K3P.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(supabaseProvider).rpc('referral_apply', params: {'p_code': code});
      ref.invalidate(myReferralsProvider);
      if (mounted) toast(context, 'Code added. Thanks!', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    } on PostgrestException catch (e) {
      setState(() => _err = challengeError(e));
    } catch (_) {
      setState(() => _err = 'Could not add it. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Did a friend invite you?', style: context.ty.sm.bold),
        Text('Add their code in your first 7 days.', style: context.ty.cap.col(context.c.textMuted)),
        const Gap(Space.s2),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: 'TOLU-7K3P', errorText: _err),
        ),
        const Gap(Space.s2),
        Btn('Add code', kind: BtnKind.tonal, block: true, loading: _busy, onPressed: _busy ? null : _apply),
      ],
    ),
  );
}

/// Home: a small invite card.
class InviteCard extends StatelessWidget {
  const InviteCard({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => openRoute(context, '/me/invite'),
    child: Row(
      children: [
        IconTile(PhosphorIcons.gift(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12),
        const Gap(Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite friends', style: context.ty.body.bold),
              Text('Get Premium cheaper for every friend who joins', style: context.ty.cap.col(context.c.textMuted)),
            ],
          ),
        ),
        Icon(PhosphorIcons.caretRight(), size: 18, color: context.c.textSubtle),
      ],
    ),
  );
}

/// Shown instead of the app when the account is banned (prototype `banned`). One appeal within 14 days.
class BannedScreen extends ConsumerStatefulWidget {
  const BannedScreen({super.key});
  @override
  ConsumerState<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends ConsumerState<BannedScreen> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _appeal() async {
    if (_reason.text.trim().length < 10) return setState(() => _err = 'Tell us what happened in a sentence or two.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(supabaseProvider).rpc('ban_appeal', params: {'p_reason': _reason.text.trim()});
      final s = await ref.read(supabaseProvider).rpc('my_status');
      ref.read(accountStatusProvider.notifier).set(Map<String, dynamic>.from(s as Map));
      if (mounted) toast(context, 'Appeal sent. We reply in your email and notifications.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    } on PostgrestException catch (e) {
      setState(() => _err = challengeError(e));
    } catch (_) {
      setState(() => _err = 'Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(accountStatusProvider) ?? const {};
    final c = context.c;
    final appeal = s['appeal'] is Map ? Map<String, dynamic>.from(s['appeal'] as Map) : null;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Space.s5),
            children: [
              const Gap(Space.s6),
              StateBlock(
                icon: PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
                tone: Tone.red,
                title: 'Your account is banned',
                text: '${s['ban_reason'] ?? 'This account broke the rules.'} You cannot use SolutionTee CBT with this account.',
              ),
              const Gap(Space.s4),
              if (appeal != null)
                InfoBanner(
                  kind: appeal['status'] == 'rejected' ? BannerKind.warn : BannerKind.info,
                  icon: PhosphorIcons.scales(PhosphorIconsStyle.fill),
                  child: Text(
                    appeal['status'] == 'pending'
                        ? 'We have your appeal and will reply soon.'
                        : appeal['status'] == 'rejected'
                        ? 'Your appeal was not accepted.${(appeal['note'] ?? '').toString().isEmpty ? '' : ' ${appeal['note']}'}'
                        : 'Your appeal was accepted. Close and open the app again.',
                  ),
                )
              else if (s['can_appeal'] == true) ...[
                Text('Think this is a mistake?', style: context.ty.body.bold),
                Text('You can send one appeal within 14 days.', style: context.ty.cap.col(c.textMuted)),
                const Gap(Space.s2),
                TextField(
                  controller: _reason,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(hintText: 'Explain what happened', errorText: _err),
                ),
                Btn('Send appeal', block: true, loading: _busy, onPressed: _busy ? null : _appeal),
              ] else
                Text('The time to appeal has passed.', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
              const Gap(Space.s4),
              Btn('Contact support', kind: BtnKind.outline, block: true, onPressed: () => context.push('/help')),
              const Gap(Space.s2),
              Btn('Log out', kind: BtnKind.ghost, block: true, onPressed: () => signOutAndWipe(ref)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when this phone already has another account (D-032). The admin can allow it (for example brothers and sisters).
class PhoneTakenScreen extends ConsumerWidget {
  const PhoneTakenScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            const Gap(Space.s6),
            StateBlock(
              icon: PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
              tone: Tone.gold,
              title: 'This phone already has an account',
              text: 'SolutionTee CBT allows one account per phone, so rewards and prizes stay fair. Log in with the first account on this phone.',
            ),
            const Gap(Space.s4),
            InfoBanner(
              icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
              child: const Text('Sharing this phone with a brother or sister? Contact support and we can allow a second account.'),
            ),
            const Gap(Space.s4),
            Btn('Log in with another account', block: true, onPressed: () => signOutAndWipe(ref)),
            const Gap(Space.s2),
            Btn('Contact support', kind: BtnKind.outline, block: true, onPressed: () => context.push('/help')),
          ],
        ),
      ),
    ),
  );
}

/// This phone is banned (D-079): no account can be made or used on it. The person can send one appeal with an
/// email to reply to — no account needed.
class PhoneBannedScreen extends ConsumerStatefulWidget {
  const PhoneBannedScreen({super.key});
  @override
  ConsumerState<PhoneBannedScreen> createState() => _PhoneBannedScreenState();
}

class _PhoneBannedScreenState extends ConsumerState<PhoneBannedScreen> {
  final _email = TextEditingController(), _reason = TextEditingController();
  Map<String, dynamic>? _status;
  bool _busy = false, _sent = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<List<String?>> _ids() async => (await DeviceCheck.ids()).list;

  Future<void> _load() async {
    try {
      final j = await Supabase.instance.client.rpc('device_status', params: {'p_ids': await _ids()}).timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _status = Map<String, dynamic>.from(j as Map));
    } catch (_) {}
  }

  Future<void> _appeal() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Supabase.instance.client.rpc('device_appeal', params: {'p_ids': await _ids(), 'p_email': _email.text.trim(), 'p_reason': _reason.text.trim()});
      setState(() => _sent = true);
      await _load();
    } on PostgrestException catch (e) {
      setState(() => _err = challengeError(e));
    } catch (_) {
      setState(() => _err = 'Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    var signedIn = false;
    try {
      signedIn = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {}
    final reason = _status?['reason'] ?? ref.watch(accountStatusProvider)?['phone_ban_reason'];
    final appeal = _status?['appeal'] is Map ? Map<String, dynamic>.from(_status!['appeal'] as Map) : null;
    final waiting = _sent || appeal?['status'] == 'pending';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Space.s5),
            children: [
              const Gap(Space.s6),
              StateBlock(
                icon: PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
                tone: Tone.red,
                title: 'This phone is banned',
                text: '${reason ?? 'This phone broke the rules.'} No account can be created or used on this phone.',
              ),
              const Gap(Space.s4),
              if (waiting)
                InfoBanner(icon: PhosphorIcons.scales(PhosphorIconsStyle.fill), child: const Text('We have your appeal. We will reply by email.'))
              else if (appeal?['status'] == 'rejected')
                InfoBanner(
                  kind: BannerKind.warn,
                  icon: PhosphorIcons.scales(PhosphorIconsStyle.fill),
                  child: Text('Your last appeal was not accepted.${(appeal?['note'] ?? '').toString().isEmpty ? '' : ' ${appeal!['note']}'}'),
                ),
              if (!waiting) ...[
                const Gap(Space.s3),
                Text('Think this is a mistake?', style: context.ty.body.bold),
                Text('Send an appeal. Tell us who uses this phone and what happened.', style: context.ty.cap.col(c.textMuted)),
                const Gap(Space.s2),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Your email (we reply here)'),
                ),
                const Gap(Space.s2),
                TextField(
                  controller: _reason,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(hintText: 'Explain what happened', errorText: _err),
                ),
                Btn('Send appeal', block: true, loading: _busy, onPressed: _busy ? null : _appeal),
              ],
              const Gap(Space.s4),
              Btn('Contact support', kind: BtnKind.outline, block: true, onPressed: () => context.push('/help')),
              if (signedIn) ...[const Gap(Space.s2), Btn('Log out', kind: BtnKind.ghost, block: true, onPressed: () => signOutAndWipe(ref))],
            ],
          ),
        ),
      ),
    );
  }
}

/// This copy of the app runs as a dual app, inside an app cloner, or as another Android user (D-079).
class CloneBlockedScreen extends StatelessWidget {
  const CloneBlockedScreen({super.key});
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            const Gap(Space.s6),
            StateBlock(
              icon: PhosphorIcons.copy(PhosphorIconsStyle.fill),
              tone: Tone.gold,
              title: 'Use the original app',
              text:
                  'This copy of SolutionTee CBT is running as a dual app, inside an app cloner or in a second profile. '
                  'That is not allowed, so rewards and prizes stay fair.',
            ),
            const Gap(Space.s4),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to fix it', style: context.ty.sm.bold),
                  const Gap(Space.s2),
                  for (final t in [
                    'Close this copy and remove it (Settings → Apps → Dual apps, or uninstall it from the cloner app).',
                    'Open SolutionTee CBT from your home screen, the app you installed from our website or the Play Store.',
                    'One account per phone. Sharing with a brother or sister? Contact support.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $t', style: context.ty.cap.col(context.c.textMuted)),
                    ),
                ],
              ),
            ),
            const Gap(Space.s4),
            Btn('Contact support', kind: BtnKind.outline, block: true, onPressed: () => context.push('/help')),
          ],
        ),
      ),
    ),
  );
}
