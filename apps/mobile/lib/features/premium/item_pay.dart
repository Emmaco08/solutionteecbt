import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import 'pay_methods.dart';
import 'payments.dart';
import 'paystack_web.dart';
import 'paywall.dart';

// naira() is shared from paywall.dart.

/// Pays for one thing sold by id (an online class, D-147; a tutor plan, D-149) with every Paystack way: the student
/// picks card, transfer, USSD or an app; the server sets the price and records what was bought. Waits up to two
/// minutes for Paystack's answer. Returns the result (PaySuccess when it is done).
Future<PayResult> payForItem(BuildContext context, WidgetRef ref, {required String itemRef, required String title, required int priceKobo}) async {
  var method = PayMethod.card;
  var bank = '737';
  final fee = ref.read(paySettingsProvider).paystackFeeKobo(priceKobo);
  final price = fee > 0 ? '${naira(priceKobo + fee)} (incl. ${naira(fee)} processing fee)' : naira(priceKobo);
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
                child: Text(title, style: ctx.ty.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const Gap(Space.s2),
              Text(naira(priceKobo + fee), style: ctx.ty.h3.tnum),
            ],
          ),
          if (fee > 0) Text('Includes ${naira(fee)} processing fee', style: ctx.ty.cap.col(ctx.c.textMuted)),
          const Gap(Space.s4),
          PayMethodPicker(method: method, bank: bank, onChanged: (m, b) => set(() => (method = m, bank = b))),
          const Gap(Space.s4),
          Btn('Pay $price', block: true, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    ),
  );
  if (go != true || !context.mounted) return PayCancelled();
  final p = ref.read(paymentProvider(true)) as PaystackProvider;
  p.dark = Theme.of(context).brightness == Brightness.dark;
  var r = await p.buyItem('item', itemRef, channel: payChannel(method, bank));
  if (!context.mounted) return r;
  if (r is PayOffline) r = await showPayOffline(context, r, p, what: title) ?? PayPending(r.reference);
  if (!context.mounted) return r;
  if (r is PayWeb) r = await showPaystackWeb(context, r, p, what: title, via: method.viaName) ?? PayPending(r.reference);
  if (r is PayPending && r.reference != null) {
    final reference = r.reference!;
    for (var i = 0; i < 24 && context.mounted; i++) {
      r = await p.check(reference);
      if (r is! PayPending) break;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
  return r;
}
