import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/math_text.dart';
import '../../widgets/r2_image.dart';
import '../../widgets/states.dart';
import 'challenges_screens.dart' show Ticker;
import 'compete_data.dart';

String _clock(String iso) {
  final t = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Result while live (`challenge-result`) and the winners at close (`challenge-winners`): one screen, server data.
class ChallengeResultScreen extends ConsumerWidget {
  const ChallengeResultScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(challengeResultProvider(id));
    final c = context.c;
    return Scaffold(
      appBar: TopBar(title: v.value?['title'] as String? ?? 'Result', onBack: () => context.canPop() ? context.pop() : context.go('/test/challenges')),
      body: asyncView(
        v,
        (d) {
          final ch = Challenge(d);
          final mine = ch.mine;
          final top = rows(d['top']);
          final myRank = (d['my_rank'] as num?)?.toInt();
          final ended = ch.ended;
          final prize = (mine?['prize'] as num?)?.toInt() ?? 0;
          final won = ended && prize > 0;
          final claim = d['claim'] is Map ? Map<String, dynamic>.from(d['claim'] as Map) : null;
          final rm = context.reduceMotion;
          final sections = <Widget>[
            if (won)
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconTile(PhosphorIcons.trophy(PhosphorIconsStyle.fill), tone: Tone.gold, size: 48, radius: 24),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Congratulations!', style: context.ty.cap.bold.col(c.onAccentSoft)),
                              Text('You won ${nairaWhole(prize)}', style: context.ty.h2),
                              Text('#${mine?['rank']} of ${ch.joined} students.', style: context.ty.sm),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(Space.s3),
                    if (claim == null)
                      Btn(
                        'Send my account details',
                        kind: BtnKind.accent,
                        block: true,
                        leading: PhosphorIcons.bank(PhosphorIconsStyle.fill),
                        onPressed: () => openRoute(context, '/test/challenges/$id/claim'),
                      )
                    else
                      InfoBanner(
                        kind: claim['status'] == 'paid' ? BannerKind.ok : BannerKind.info,
                        child: Text(
                          claim['status'] == 'paid'
                              ? 'Paid. The proof is on the Winners wall.'
                              : claim['status'] == 'rejected'
                              ? 'There is a problem with your claim. Contact support.'
                              : 'We have your account details. Prizes are paid within 3 working days after the fair-play review.',
                        ),
                      ),
                  ],
                ),
              ).animate(target: rm ? 0 : 1).scale(begin: const Offset(.95, .95), end: const Offset(1, 1), duration: Motion.slow, curve: Motion.out),
            if (mine != null && !won)
              AppCard(
                child: Column(
                  children: [
                    if (mine['status'] == 'disqualified') ...[
                      Pill('Disqualified', kind: BadgeKind.error, icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill)),
                      const Gap(Space.s2),
                      Text('${mine['dq_reason'] ?? 'You left the challenge screen.'}', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                      const Gap(Space.s3),
                      AppealStatus(challengeId: id, mine: mine),
                    ] else ...[
                      Pill('Fair-play check passed', kind: BadgeKind.success, icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
                      const Gap(Space.s3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${mine['score']}', style: context.ty.display.tnum),
                            TextSpan(text: '/${ch.questions}', style: context.ty.h2.col(c.textMuted)),
                          ],
                        ),
                      ),
                      Text(
                        'Finished in ${mmss(mine['time_ms'] as num? ?? 0)} · started ${_clock('${mine['started_at']}')}',
                        style: context.ty.sm.col(c.textMuted),
                      ),
                      const Gap(Space.s3),
                      if (myRank != null) Text(ended ? 'You finished #$myRank' : 'You are #$myRank right now', style: context.ty.h2),
                      const Gap(Space.s1),
                      Text(
                        ended
                            ? 'A new challenge comes soon.'
                            : ch.prizes.isNotEmpty && myRank != null && myRank <= ch.prizes.length
                            ? 'Stay in the top ${ch.prizes.length} until it closes to win ${nairaWhole(ch.prizes[myRank - 1])}.'
                            : 'Keep practising. A new challenge comes every week.',
                        style: context.ty.sm.col(c.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(ended ? 'Winners' : 'Live ranking', style: context.ty.body.bold)),
                      Text('${ch.joined} students', style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                  const Gap(Space.s2),
                  if (top.isEmpty) Text('Nobody has finished yet.', style: context.ty.sm.col(c.textMuted)),
                  for (final w in top)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: Space.s2),
                      decoration: BoxDecoration(color: w['me'] == true ? c.secondarySoft : null, borderRadius: BorderRadius.circular(Radii.sm)),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${w['rank']}', style: context.ty.sm.bold.tnum)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w['me'] == true ? 'You' : '${w['name']}  ${w['state'] ?? ''}', style: context.ty.sm.bold),
                                Text('Started ${_clock('${w['started_at']}')}', style: context.ty.cap.col(c.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${w['score']}/${ch.questions} · ${mmss(w['time_ms'] as num? ?? 0)}', style: context.ty.sm.bold.tnum),
                              if ((w['prize'] as num? ?? 0) > 0) Text(nairaWhole(w['prize'] as num), style: context.ty.cap.bold.col(c.onAccentSoft)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  side: BorderSide(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Text('How winners are decided', style: context.ty.sm.bold),
                  childrenPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
                  children: [Text(ch.rule, style: context.ty.sm)],
                ),
              ),
            ),
            if (!ended)
              InfoBanner(
                icon: PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                child: Ticker(
                  builder: (_) =>
                      Text('Winners are announced the moment it closes (in ${untilShort(ch.endsAt)}). Winners get a form to send their account details.'),
                ),
              )
            else
              InfoBanner(
                kind: BannerKind.ok,
                icon: PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                child: GestureDetector(
                  onTap: () => openRoute(context, '/test/winners-wall'),
                  child: const Text('After we pay the winners, the proof of payment is posted on the Winners wall.'),
                ),
              ),
            if (ended && mine != null && mine['status'] != 'playing' && ch.j['allow_review'] == false)
              Text('Answer review is turned off for this challenge.', style: context.ty.cap.col(c.textMuted), textAlign: TextAlign.center),
            if (ended && mine?['can_review'] == true)
              Btn(
                'Review my answers',
                kind: BtnKind.tonal,
                block: true,
                leading: PhosphorIcons.listChecks(PhosphorIconsStyle.fill),
                onPressed: () => openRoute(context, '/test/challenges/$id/review'),
              ),
            Btn('See other challenges', kind: BtnKind.outline, block: true, onPressed: () => context.go('/test/challenges')),
          ];
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(challengeResultProvider(id)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[if (i > 0) const Gap(Space.s3), sections[i]],
                  ],
                ),
              ),
              if (!rm && (won || (mine != null && mine['status'] == 'finished' && (mine['score'] as num? ?? 0) >= ch.questions - 1 && ch.questions > 0)))
                const IgnorePointer(child: Confetti()),
            ],
          );
        },
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: const [
            Skeleton(height: 180, radius: Radii.lg),
            Gap(Space.s3),
            Skeleton(height: 260, radius: Radii.lg),
          ],
        ),
        onRetry: () => ref.invalidate(challengeResultProvider(id)),
      ),
    );
  }
}

const banks = [
  'Access Bank',
  'Ecobank',
  'Fidelity Bank',
  'First Bank',
  'FCMB',
  'GTBank',
  'Keystone Bank',
  'Kuda',
  'Moniepoint',
  'OPay',
  'PalmPay',
  'Polaris Bank',
  'Stanbic IBTC',
  'Sterling Bank',
  'UBA',
  'Union Bank',
  'Wema Bank',
  'Zenith Bank',
];

/// Claim the prize (prototype `claim-prize`): age, guardian for under-18, bank and the 10-digit account. Never a PIN.
class ClaimPrizeScreen extends ConsumerStatefulWidget {
  const ClaimPrizeScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ClaimPrizeScreen> createState() => _ClaimPrizeScreenState();
}

class _ClaimPrizeScreenState extends ConsumerState<ClaimPrizeScreen> {
  bool _adult = true;
  String? _bank;
  final _acc = TextEditingController(), _name = TextEditingController(), _gName = TextEditingController(), _gPhone = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_acc, _name, _gName, _gPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final acc = _acc.text.replaceAll(RegExp(r'\s'), '');
    setState(() => _err = null);
    if (_bank == null || !RegExp(r'^\d{10}$').hasMatch(acc)) return setState(() => _err = 'Choose your bank and enter the 10-digit account number.');
    if (_name.text.trim().length < 3) return setState(() => _err = 'Write the name on the account.');
    if (!_adult && (_gName.text.trim().isEmpty || _gPhone.text.trim().length < 7)) {
      return setState(() => _err = 'Add your parent or guardian\'s name and phone number.');
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(supabaseProvider)
          .rpc(
            'prize_claim',
            params: {
              'p_id': widget.id,
              'p_adult': _adult,
              'p_bank': _bank,
              'p_account_number': acc,
              'p_account_name': _name.text.trim(),
              'p_guardian_name': _adult ? null : _gName.text.trim(),
              'p_guardian_phone': _adult ? null : _gPhone.text.trim(),
            },
          );
      ref.invalidate(challengeResultProvider(widget.id));
      if (!mounted) return;
      toast(context, 'Sent. Your prize is waiting for the fair-play review.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      context.go('/me/winnings');
    } on PostgrestException catch (e) {
      setState(() => _err = e.message);
    } catch (_) {
      setState(() => _err = 'Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = ref.watch(challengeResultProvider(widget.id)).value;
    final prize = (d?['mine'] is Map ? (d!['mine'] as Map)['prize'] as num? : null) ?? 0;
    return Scaffold(
      appBar: const TopBar(title: 'Get your prize'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Row(
              children: [
                Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill), color: c.onAccentSoft, size: 28),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nairaWhole(prize), style: context.ty.h2.tnum),
                      Text('${d?['title'] ?? ''} · pending review', style: context.ty.cap),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(Space.s4),
          Text(
            'Send the account we should pay. We transfer the prize within 3 working days, then post the proof on the Winners wall (your account number is hidden).',
            style: context.ty.sm.col(c.textMuted),
          ),
          const Gap(Space.s4),
          Text('Are you 18 or older?', style: context.ty.label),
          const Gap(Space.s2),
          Seg<bool>(value: _adult, items: const [(true, 'Yes, 18+'), (false, 'No, under 18')], onChanged: (v) => setState(() => _adult = v)),
          if (!_adult) ...[
            const Gap(Space.s3),
            InfoBanner(
              icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
              child: const Text('Because you are under 18, the prize is paid to your parent or guardian, and they must agree.'),
            ),
            const Gap(Space.s3),
            Field(label: 'Parent or guardian full name', controller: _gName),
            const Gap(Space.s3),
            Field(label: 'Their phone number', controller: _gPhone, keyboard: TextInputType.phone, hint: '0803 000 0000'),
          ],
          const Gap(Space.s4),
          Text('Bank', style: context.ty.label),
          const Gap(Space.s2),
          DropdownButtonFormField<String>(
            initialValue: _bank,
            items: [for (final b in banks) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => setState(() => _bank = v),
            decoration: const InputDecoration(hintText: 'Choose bank'),
          ),
          const Gap(Space.s3),
          Field(label: 'Account number', controller: _acc, keyboard: TextInputType.number, hint: '10 digits', maxLength: 10),
          const Gap(Space.s3),
          Field(label: 'Name on the account', controller: _name, help: _adult ? 'It must match your name.' : 'It must match your parent or guardian\'s name.'),
          if (_err != null) ...[const Gap(Space.s3), ErrText(_err!)],
          const Gap(Space.s3),
          Text('We never ask for your PIN, password or card details.', style: context.ty.cap.col(c.textSubtle)),
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Btn('Send my account details', block: true, loading: _busy, onPressed: _busy ? null : _send),
      ),
    );
  }
}

/// Me → My winnings (prototype `winnings`).
class WinningsScreen extends ConsumerWidget {
  const WinningsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(winningsProvider);
    final c = context.c;
    return Scaffold(
      appBar: const TopBar(title: 'My winnings'),
      body: asyncView(v, (d) {
        final items = rows(d['items']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
          children: [
            Container(
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Row(
                children: [
                  Icon(PhosphorIcons.wallet(PhosphorIconsStyle.fill), color: c.onAccentSoft, size: 28),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total won', style: context.ty.cap),
                        Text(nairaWhole(d['total'] as num? ?? 0), style: context.ty.h1.tnum),
                      ],
                    ),
                  ),
                  Pill('${nairaWhole(d['paid'] as num? ?? 0)} paid', kind: BadgeKind.success),
                ],
              ),
            ),
            const Gap(Space.s4),
            if (items.isEmpty)
              StateBlock(
                icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                tone: Tone.gold,
                title: 'No winnings yet',
                text: 'Join a challenge. Winners are paid after a fair-play review.',
              )
            else
              ListCard(
                children: [
                  for (final w in items)
                    ListRow(
                      icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                      tone: Tone.gold,
                      title: '${w['title']}',
                      caption: (w['prize'] as num? ?? 0) > 0
                          ? '#${w['rank']} · ${switch (w['claim']) {
                              'paid' => 'paid to ${w['bank'] ?? 'your bank'}',
                              'submitted' => 'pending fair-play review',
                              'rejected' => 'claim rejected · contact support',
                              _ => 'send your account details',
                            }}'
                          : '#${w['rank']} · ${w['premium_days']} days of Premium added',
                      trailing: Text((w['prize'] as num? ?? 0) > 0 ? nairaWhole(w['prize'] as num) : 'Reward', style: context.ty.sm.bold),
                      onTap: () => openRoute(context, '/test/challenges/${w['challenge_id']}/result'),
                    ),
                ],
              ),
            const Gap(Space.s3),
            Text('Questions about a prize? Me → Help & support.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ],
        );
      }, onRetry: () => ref.invalidate(winningsProvider)),
    );
  }
}

/// Winners wall (prototype `winners-wall`): proof that we pay. Account numbers and balances are hidden on receipts.
class WinnersWallScreen extends ConsumerWidget {
  const WinnersWallScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(winnersWallProvider);
    final c = context.c;
    return Scaffold(
      appBar: const TopBar(title: 'Winners wall', subtitle: 'Proof that we pay our winners'),
      body: asyncView(v, (d) {
        final items = rows(d['items']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
          children: [
            Container(
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Row(
                children: [
                  Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), color: c.success, size: 28),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paid to winners so far', style: context.ty.cap),
                        Text(nairaWhole(d['total'] as num? ?? 0), style: context.ty.h1.tnum),
                      ],
                    ),
                  ),
                  Text('${d['count'] ?? 0} winners\npaid', style: context.ty.cap, textAlign: TextAlign.right),
                ],
              ),
            ),
            const Gap(Space.s4),
            if (items.isEmpty)
              StateBlock(
                icon: PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                tone: Tone.green,
                title: 'No payments posted yet',
                text: 'After we pay the first winners, the proof shows here.',
              ),
            for (final p in items) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Avatar('${p['name']}', size: 40),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p['name']}  ${p['state'] ?? ''}', style: context.ty.sm.bold),
                              Text('${p['place']} · ${p['title']}', style: context.ty.cap.col(c.textMuted)),
                            ],
                          ),
                        ),
                        Text(nairaWhole(p['amount'] as num), style: context.ty.body.bold.tnum),
                      ],
                    ),
                    if ((p['receipt'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(Space.s3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: R2Image(imageKey: p['receipt'] as String, decodeWidth: 800, semanticLabel: 'Proof of payment'),
                      ),
                    ],
                    if ((p['note'] as String?)?.isNotEmpty ?? false) ...[const Gap(Space.s2), Text('“${p['note']}”', style: context.ty.sm)],
                  ],
                ),
              ),
              const Gap(Space.s3),
            ],
            Text(
              'Account numbers and balances are hidden. Winners under 18 are paid through a parent or guardian and are shown by first name only.',
              style: context.ty.cap.col(c.textSubtle),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }, onRetry: () => ref.invalidate(winnersWallProvider)),
    );
  }
}

/// Appeal a disqualification (D-073): what happened, plus an optional screenshot (for example of the call that came in).
/// Within 24 hours; the admin accepts (the entry counts again) or rejects, and the student gets a notification.
class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _reason = TextEditingController();
  XFile? _shot;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (x != null && mounted) setState(() => _shot = x);
  }

  Future<void> _send() async {
    if (_reason.text.trim().length < 10) return setState(() => _err = 'Tell us what happened in a short sentence or two.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      String? key;
      if (_shot != null) {
        final bytes = await File(_shot!.path).readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) throw const FormatException('too big');
        final type = _shot!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        final (k, url) = await ref.read(apiProvider).appealUploadLink(bytes.length, type);
        final r = await http.put(Uri.parse(url), headers: {'content-type': type}, body: bytes).timeout(const Duration(seconds: 60));
        if (r.statusCode >= 300) throw Exception('upload');
        key = k;
      }
      await ref.read(supabaseProvider).rpc('challenge_appeal', params: {'p_id': widget.id, 'p_reason': _reason.text.trim(), 'p_image': key});
      ref.invalidate(challengeProvider(widget.id));
      ref.invalidate(challengeResultProvider(widget.id));
      if (!mounted) return;
      toast(context, 'Appeal sent. We will reply in your notifications.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      context.pop();
    } on PostgrestException catch (e) {
      setState(() => _err = e.message);
    } on FormatException {
      setState(() => _err = 'That picture is too big. Choose a smaller screenshot.');
    } catch (_) {
      setState(() => _err = 'Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: const TopBar(title: 'Send an appeal'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          InfoBanner(
            icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
            child: const Text(
              'Was it a phone call, a crash or something you could not control? Explain what happened. A screenshot helps (for example of the missed call). Send it within 24 hours.',
            ),
          ),
          const Gap(Space.s4),
          Text('What happened?', style: context.ty.label),
          const Gap(Space.s2),
          TextField(
            controller: _reason,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'e.g. A call came in at 8:12 pm and covered the screen. I did not open another app.'),
          ),
          const Gap(Space.s3),
          Text('Screenshot (optional)', style: context.ty.label),
          const Gap(Space.s2),
          if (_shot != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Image.file(File(_shot!.path), height: 200, fit: BoxFit.cover),
            ),
          const Gap(Space.s2),
          Btn(
            _shot == null ? 'Add a screenshot' : 'Change the screenshot',
            kind: BtnKind.outline,
            block: true,
            leading: PhosphorIcons.image(PhosphorIconsStyle.fill),
            onPressed: _busy ? null : _pick,
          ),
          if (_err != null) ...[const Gap(Space.s3), ErrText(_err!)],
          const Gap(Space.s3),
          Text('Our team checks every appeal. If it is accepted, your entry counts again.', style: context.ty.cap.col(c.textSubtle)),
        ],
      ),
      bottomNavigationBar: FooterCta(
        child: Btn('Send the appeal', block: true, loading: _busy, onPressed: _busy ? null : _send),
      ),
    );
  }
}

/// Appeal state for a disqualified entry: the button within 24 hours, or where the appeal stands.
class AppealStatus extends StatelessWidget {
  const AppealStatus({super.key, required this.challengeId, required this.mine});
  final String challengeId;
  final Map<String, dynamic> mine;
  @override
  Widget build(BuildContext context) {
    if (mine['status'] != 'disqualified' && mine['appeal'] == null) return const SizedBox.shrink();
    final a = mine['appeal'] is Map ? Map<String, dynamic>.from(mine['appeal'] as Map) : null;
    if (a != null) {
      final s = a['status'];
      return InfoBanner(
        kind: s == 'accepted'
            ? BannerKind.ok
            : s == 'rejected'
            ? BannerKind.err
            : BannerKind.info,
        icon: PhosphorIcons.scales(PhosphorIconsStyle.fill),
        child: Text(
          s == 'accepted'
              ? 'Your appeal was accepted. Your entry counts again.${(a['note'] ?? '').toString().isNotEmpty ? ' ${a['note']}' : ''}'
              : s == 'rejected'
              ? 'Your appeal was not accepted.${(a['note'] ?? '').toString().isNotEmpty ? ' ${a['note']}' : ''}'
              : 'Your appeal is waiting for our team. We will tell you in your notifications.',
        ),
      );
    }
    final finished = DateTime.tryParse('${mine['finished_at'] ?? ''}');
    if (finished != null && DateTime.now().difference(finished).inHours >= 24) {
      return const InfoBanner(kind: BannerKind.warn, child: Text('The 24 hours to appeal have passed.'));
    }
    return Btn(
      'Send an appeal',
      kind: BtnKind.outline,
      block: true,
      leading: PhosphorIcons.scales(PhosphorIconsStyle.fill),
      onPressed: () => openRoute(context, '/test/challenges/$challengeId/appeal'),
    );
  }
}

/// After a challenge ends: each of the student's questions, their choice, the right answer and the explanation (D-074).
/// The server only sends this once the challenge has ended, so answers cannot be shared while it runs.
/// Screenshots and screen recording are blocked here too, so the questions are not shared (D-075).
class ChallengeReviewScreen extends ConsumerStatefulWidget {
  const ChallengeReviewScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ChallengeReviewScreen> createState() => _ChallengeReviewScreenState();
}

class _ChallengeReviewScreenState extends ConsumerState<ChallengeReviewScreen> {
  StreamSubscription<MethodCall>? _secure;

  @override
  void initState() {
    super.initState();
    SecureScreen.on();
    _secure = SecureScreen.watch(
      onScreenshot: () => _warn('Screenshots are not allowed in challenge reviews.'),
      onRecording: () => _warn('Screen recording is not allowed here. The screen will look black.'),
    );
  }

  void _warn(String text) {
    if (mounted && SecureScreen.protecting) toast(context, text, icon: PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill));
  }

  @override
  void dispose() {
    _secure?.cancel();
    SecureScreen.off();
    super.dispose();
  }

  String get id => widget.id;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(challengeReviewProvider(id));
    final c = context.c;
    return Scaffold(
      appBar: TopBar(title: 'Review my answers', subtitle: v.value == null ? null : '${v.value!['score']}/${v.value!['total']} right'),
      body: asyncView(
        v,
        (d) {
          final items = rows(d['items']);
          if (items.isEmpty) {
            return Center(
              child: StateBlock(icon: PhosphorIcons.listChecks(PhosphorIconsStyle.fill), title: 'Nothing to review', text: 'You did not answer any questions.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Gap(Space.s3),
            itemBuilder: (_, i) {
              final q = items[i];
              final opts = q['options'] is Map ? Map<String, dynamic>.from(q['options'] as Map) : const <String, dynamic>{};
              final answer = '${q['answer']}', choice = q['choice'] as String?;
              final right = q['correct'] == true;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('${q['n']}.', style: context.ty.sm.bold.tnum),
                        const Gap(Space.s2),
                        Expanded(
                          child: Text(
                            [q['subject'], levelName('${q['level']}')].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
                            style: context.ty.cap.col(c.textMuted),
                          ),
                        ),
                        Pill(
                          right ? 'Right' : (choice == null ? 'No answer' : 'Wrong'),
                          kind: right ? BadgeKind.success : (choice == null ? BadgeKind.neutral : BadgeKind.error),
                        ),
                      ],
                    ),
                    const Gap(Space.s2),
                    MathText('${q['body']}', style: context.ty.body),
                    const Gap(Space.s2),
                    for (final k in opts.keys.toList()..sort())
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                        decoration: BoxDecoration(
                          color: k == answer ? c.successSoft : (k == choice ? c.errorSoft : c.surfaceAlt),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 24, child: Text(k, style: context.ty.sm.bold)),
                            Expanded(child: MathText('${opts[k]}', style: context.ty.sm)),
                            if (k == answer) Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 18, color: c.success),
                            if (k == choice && k != answer) Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), size: 18, color: c.error),
                          ],
                        ),
                      ),
                    if ('${q['explanation'] ?? ''}'.trim().isNotEmpty) ...[
                      const Gap(Space.s3),
                      Text('Explanation', style: context.ty.cap.bold),
                      MathText('${q['explanation']}', style: context.ty.sm.col(c.textMuted)),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            for (var i = 0; i < 3; i++) ...[const Skeleton(height: 220, radius: Radii.lg), const Gap(Space.s3)],
          ],
        ),
        onRetry: () => ref.invalidate(challengeReviewProvider(id)),
      ),
    );
  }
}
