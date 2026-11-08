import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'pay_methods.dart';
import 'payments.dart';
import 'paystack_web.dart';
import 'paywall.dart';

/// How a locked study item or exam year opens (D-106): the admin's choice per kind and per item — Premium, watch N
/// rewarded videos (free students), or pay for this one item (Paystack, yours for good). The server says what applies
/// (`content_offer`) and checks every unlock. [kind] is 'item' (study item id) or 'year' ("examId:year").
Future<void> showContentOffer(
  BuildContext context, {
  required String kind,
  required String itemRef,
  required String title,
  String? paywallReason,
  String? itemKind,
  VoidCallback? onOpened,
}) async {
  final container = ProviderScope.containerOf(context);
  Map<String, dynamic> o;
  try {
    o = Map<String, dynamic>.from(await container.read(supabaseProvider).rpc('content_offer', params: {'p_kind': kind, 'p_ref': itemRef}) as Map);
  } catch (_) {
    if (context.mounted) showPaywall(context, reason: paywallReason);
    return;
  }
  if (!context.mounted) return;
  if (o['open'] == true) {
    onOpened?.call();
    return;
  }
  final offer = ContentOffer(o, itemKind: itemKind);
  if (!offer.canWatch && !offer.canPay && offer.watchBlock != 'unlock_cap') {
    showPaywall(context, reason: paywallReason);
    return;
  }
  await showSheet<void>(
    context,
    builder: (_) => _OfferSheet(kind: kind, itemRef: itemRef, title: title, offer: offer, paywallReason: paywallReason, onOpened: onOpened),
  );
}

/// The server's answer, read for the sheet.
class ContentOffer {
  ContentOffer(this.j, {this.itemKind});
  final Map<String, dynamic> j;
  final String? itemKind;
  String get mode => '${j['mode'] ?? 'default'}';
  int _i(String k) => (j[k] as num?)?.toInt() ?? 0;
  int get ads => _i('ads') < 1 ? 1 : _i('ads');
  int get progress => _i('progress');
  int get priceKobo => _i('price_kobo');
  bool get premium => j['premium'] == true;
  bool get premiumPays => j['premium_pays'] == true;
  bool get adsOn => j['ads_on'] == true && _i('rewarded_left') > 0;

  /// Minutes the unlock lasts (0 = for good).
  int get minutes => j['minutes'] != null ? _i('minutes') : (_i('hours') == 0 && mode == 'ads' ? 0 : _i('hours') * 60);

  /// Which reward the videos count toward: an item set to "watch ads", a year (its own rule or the default one), or a
  /// Premium note under the default rules (1 video, the note hours).
  String? get rewardKind => mode == 'ads'
      ? (j.containsKey('kind') ? 'item' : 'year')
      : mode == 'default' && !j.containsKey('kind')
      ? 'year'
      : mode == 'default' && itemKind == 'note'
      ? 'note'
      : null;
  bool get canWatch => !premium && adsOn && rewardKind != null && j['watch_ok'] != false;

  /// Why watching is not offered now: 'unlock_cap' (today's limit reached) or 'not_allowed' (the admin keeps it Premium).
  String? get watchBlock => j['watch_block'] as String?;
  // Pay per item uses Paystack: only in the direct (website) app. Google Play does not allow other payment systems
  // for digital items in the Play Store app.
  bool get canPay => store != Store.play && mode == 'pay' && priceKobo >= 5000 && (!premium || premiumPays);
}

String _time(int minutes) => minutes == 0
    ? 'for good'
    : minutes % 1440 == 0
    ? 'for ${minutes ~/ 1440 == 1 ? '1 day' : '${minutes ~/ 1440} days'}'
    : minutes % 60 == 0
    ? 'for ${minutes == 60 ? '1 hour' : '${minutes ~/ 60} hours'}'
    : 'for $minutes minutes';

String _naira(int kobo) {
  final n = kobo ~/ 100;
  final s = n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '₦$s';
}

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.kind, required this.itemRef, required this.title, required this.offer, this.paywallReason, this.onOpened});
  final String kind, itemRef, title;
  final ContentOffer offer;
  final String? paywallReason;
  final VoidCallback? onOpened;
  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  late int _count = widget.offer.progress;
  bool _busy = false;
  String? _waiting;

  ContentOffer get o => widget.offer;
  int get _need => o.rewardKind == 'note' ? 1 : o.ads;

  void _opened(String message) {
    HapticFeedback.mediumImpact();
    ref.invalidate(openYearsProvider);
    toast(context, message, icon: PhosphorIcons.lockSimpleOpen(PhosphorIconsStyle.fill));
    Navigator.of(context).pop();
    widget.onOpened?.call();
  }

  Future<void> _watch() async {
    setState(() => _busy = true);
    final rk = o.rewardKind!;
    final r = await watchForReward(
      context,
      ref,
      kind: rk,
      itemRef: rk == 'year' || rk == 'item' || rk == 'note' ? widget.itemRef : null,
      placement: 'open_$rk',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.counted) _count = r.count;
    });
    if (r.granted) _opened('${widget.title} is open ${_time(o.rewardKind == 'note' ? 24 * 60 : o.minutes)}.');
  }

  PaystackProvider get _pay => ref.read(paymentProvider(true)) as PaystackProvider;

  Future<void> _buy() async {
    var method = PayMethod.card;
    var bank = '737';
    final price = _naira(o.priceKobo);
    final go = await showSheet<bool>(
      context,
      closeButton: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: ctx.ty.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text(price, style: ctx.ty.h3.tnum),
              ],
            ),
            const Gap(Space.s4),
            PayMethodPicker(method: method, bank: bank, onChanged: (m, b) => set(() => (method = m, bank = b))),
            const Gap(Space.s4),
            Btn('Pay $price', block: true, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    final p = _pay..dark = Theme.of(context).brightness == Brightness.dark;
    var r = await p.buyItem(widget.kind, widget.itemRef, channel: payChannel(method, bank));
    if (!mounted) return;
    if (r is PayOffline) r = await showPayOffline(context, r, p, what: widget.title) ?? PayPending(r.reference);
    if (!mounted) return;
    if (r is PayWeb) r = await showPaystackWeb(context, r, p, what: widget.title, via: method.viaName) ?? PayPending(r.reference);
    if (!mounted) return;
    if (r is PayPending && r.reference != null) r = await _confirm(r.reference!);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PaySuccess():
        _opened('${widget.title} is yours. Thank you!');
      case PayFailed(:final message):
        toast(context, message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
      case PayCancelled():
        toast(context, 'Payment cancelled. You were not charged.', icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill));
      case PayPending():
        toast(context, 'We are waiting for Paystack. It opens by itself once your payment is confirmed.', icon: PhosphorIcons.clock(PhosphorIconsStyle.fill));
      default:
        break;
    }
  }

  /// Asks the server (which asks Paystack) for up to two minutes.
  Future<PayResult> _confirm(String reference) async {
    setState(() => _waiting = 'Confirming your payment…');
    PayResult res = PayPending(reference);
    for (var i = 0; i < 24 && mounted; i++) {
      res = await _pay.check(reference);
      if (res is! PayPending) break;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    if (mounted) setState(() => _waiting = null);
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: context.ty.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
        const Gap(Space.s1),
        Text('Choose how to open it.', style: context.ty.body.col(c.textMuted)),
        const Gap(Space.s4),
        if (o.canWatch)
          _Option(
            icon: PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
            tone: Tone.gold,
            title: _need > 1 ? 'Watch $_need short videos' : 'Watch a short video',
            text: 'Free. Opens it ${_time(o.rewardKind == 'note' ? 24 * 60 : o.minutes)}.',
            progress: _need > 1 && _count > 0 ? _count / _need : null,
            progressText: _need > 1 && _count > 0 ? '$_count of $_need watched' : null,
            action: _need > 1 && _count > 0 ? 'Next video' : 'Watch',
            busy: _busy,
            onTap: _watch,
          ),
        if (!o.canWatch && o.watchBlock == 'unlock_cap' && !o.premium)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: Text(
              'You have opened today\'s limit by watching videos. Come back tomorrow, or go Premium to open everything.',
              style: context.ty.sm.col(c.textMuted),
            ),
          ),
        if (o.canPay)
          _Option(
            icon: PhosphorIcons.wallet(PhosphorIconsStyle.fill),
            tone: Tone.green,
            title: 'Pay ${_naira(o.priceKobo)}',
            text: 'Just this one. It is yours for good.',
            action: 'Pay',
            busy: _busy,
            onTap: _buy,
          ),
        if (!o.premium)
          _Option(
            icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
            tone: Tone.navy,
            title: 'Go Premium',
            text: 'Opens everything, with no ads.',
            action: 'See plans',
            busy: false,
            onTap: () {
              Navigator.of(context).pop();
              showPaywall(context, reason: widget.paywallReason);
            },
          ),
        if (_waiting != null) ...[
          const Gap(Space.s3),
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const Gap(Space.s3),
              Text(_waiting!, style: context.ty.sm),
            ],
          ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.tone,
    required this.title,
    required this.text,
    required this.action,
    required this.busy,
    required this.onTap,
    this.progress,
    this.progressText,
  });
  final IconData icon;
  final Tone tone;
  final String title, text, action;
  final bool busy;
  final VoidCallback onTap;
  final double? progress;
  final String? progressText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s3),
    child: _Enter(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(icon, tone: tone, size: 44, radius: 12, iconSize: 22),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.ty.sm.bold),
                      Text(text, style: context.ty.cap.col(context.c.textMuted)),
                    ],
                  ),
                ),
                const Gap(Space.s2),
                Btn(action, sm: true, kind: BtnKind.tonal, loading: busy, onPressed: busy ? null : onTap),
              ],
            ),
            if (progress != null) ...[
              const Gap(Space.s3),
              ProgressBar(progress!),
              if (progressText != null) ...[const Gap(Space.s1), Text(progressText!, style: context.ty.cap)],
            ],
          ],
        ),
      ),
    ),
  );
}

/// Each option slides up and fades in (reduce motion: shown at once).
class _Enter extends StatelessWidget {
  const _Enter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
