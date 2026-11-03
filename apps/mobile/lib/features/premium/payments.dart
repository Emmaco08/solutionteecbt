import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';

/// Which shop this build sells through (D-060). Set at build time with `--flavor direct|play`.
/// `direct` (APK from the website): Paystack. `play` (Play Store): Google Play Billing.
enum Store { direct, play }

Store get store => appFlavor == 'play' ? Store.play : Store.direct;

/// Feature flags (public), e.g. paystack_in_play_build, codes_in_play_build.
final featureFlagsProvider = FutureProvider<Map<String, bool>>(
  (ref) => cached(
    ref,
    'feature_flags',
    (s) => s.from('feature_flags').select('key, enabled'),
    (j) => {for (final r in rows(j)) r['key'] as String: r['enabled'] == true},
  ),
);

/// Paystack is used in the direct build, and in the Play build only when the admin turns on
/// `paystack_in_play_build` (after Google's billing-choice programme covers Nigeria).
bool usesPaystack(WidgetRef ref) => store == Store.direct || (ref.watch(featureFlagsProvider).value?['paystack_in_play_build'] ?? false);

/// "Redeem a code" (free Premium days): always in the direct build; in the Play build only with `codes_in_play_build`.
bool showsRedeem(WidgetRef ref) => store == Store.direct || (ref.watch(featureFlagsProvider).value?['codes_in_play_build'] ?? false);

/// After a payment or a code: everything that depends on the plan is fetched again.
void refreshPlan(WidgetRef ref) {
  ref.invalidate(myPlanProvider);
  ref.invalidate(openYearsProvider);
}

/// What happened to a purchase.
sealed class PayResult {
  const PayResult();
}

class PaySuccess extends PayResult {
  const PaySuccess(this.expiresAt, {this.free = false});
  final DateTime? expiresAt;
  final bool free;
}

/// Paid or paying, but the server has not confirmed it yet (Paystack tab still open, bank transfer,
/// Google "pending" cash payment). [reference] lets the app check again.
class PayPending extends PayResult {
  const PayPending(this.reference);
  final String? reference;
}

class PayCancelled extends PayResult {
  const PayCancelled();
}

class PayFailed extends PayResult {
  const PayFailed(this.message, {this.code});
  final String message;
  final String? code;
}

/// One way to pay (SPEC §8). The server always decides the price and grants Premium; a provider only
/// starts the payment and asks the server to check it.
abstract class PaymentProvider {
  /// Whether discount codes can be typed at checkout (Google Play allows only its own promo codes).
  bool get takesCodes;

  /// Starts paying for [plan]. Paystack returns [PayPending] once its page is open; Play returns when
  /// Google's sheet closes and the server has checked the purchase.
  Future<PayResult> buy(Map<String, dynamic> plan, {String? code, String? channel});

  /// Asks the server again (Paystack: verify the reference).
  Future<PayResult> check(String reference);
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

String _fnError(FunctionException e, String fallback) {
  final d = e.details;
  if (d is Map && d['error'] is String) return d['error'] as String;
  if (d is String && d.isNotEmpty) {
    try {
      final j = jsonDecode(d);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
  }
  return fallback;
}

String? _fnCode(FunctionException e) {
  final d = e.details;
  if (d is Map && d['code'] is String) return d['code'] as String;
  return null;
}

// ---------------------------------------------------------------- Paystack (direct build)
class PaystackProvider implements PaymentProvider {
  PaystackProvider(this._sb, {this.open = _openTab});
  final SupabaseClient _sb;

  /// Opens Paystack's checkout page. Replaced in tests.
  final Future<bool> Function(Uri) open;

  static Future<bool> _openTab(Uri u) => launchUrl(u, mode: LaunchMode.inAppBrowserView);

  @override
  bool get takesCodes => true;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    try {
      final r = await _sb.functions.invoke('paystack', body: body).timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from(r.data as Map);
    } on FunctionException catch (e) {
      throw PayFailed(_fnError(e, 'Something went wrong. Please try again.'), code: _fnCode(e));
    } on TimeoutException {
      throw const PayFailed('The connection is slow. Check your data and try again.');
    } catch (e) {
      if (e is PayFailed) rethrow;
      throw const PayFailed('No internet connection. Check your data or Wi-Fi and try again.');
    }
  }

  @override
  Future<PayResult> buy(Map<String, dynamic> plan, {String? code, String? channel}) async {
    try {
      final r = await _call({'action': 'start', 'plan': plan['code'], if (code != null && code.isNotEmpty) 'code': code, 'source': 'app'});
      if (r['free'] == true) return PaySuccess(_date(r['expires_at']), free: true);
      final url = Uri.tryParse('${r['url'] ?? ''}');
      if (url == null || !url.isScheme('https')) return const PayFailed('Paystack did not open. Please try again.');
      final opened = await open(url);
      if (!opened) return const PayFailed('Could not open Paystack on this phone. Please try again.');
      return PayPending(r['reference'] as String?);
    } on PayFailed catch (e) {
      return e;
    }
  }

  @override
  Future<PayResult> check(String reference) async {
    try {
      final r = await _call({'action': 'check', 'reference': reference});
      return switch (r['status']) {
        'success' => PaySuccess(_date(r['expires_at'])),
        'failed' => const PayFailed('The payment did not go through. You were not charged. Try again or use another way to pay.', code: 'failed'),
        'needs_review' => const PayFailed(
          'We are checking this payment. If you were charged, Premium turns on after our check, or contact support.',
          code: 'review',
        ),
        'refunded' => const PayFailed('This payment was refunded.', code: 'refunded'),
        _ => PayPending(reference),
      };
    } on PayFailed catch (e) {
      return e;
    }
  }
}

// ---------------------------------------------------------------- Google Play (play build)
/// The Play account id sent with each purchase: sha256 of the user id (the server checks it matches).
String playAccountId(String userId) => sha256.convert(utf8.encode('solutiontee:$userId')).toString();

class PlayBilling implements PaymentProvider {
  PlayBilling(this._sb);
  final SupabaseClient _sb;
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _waiting = <String, Completer<PayResult>>{};
  final Map<String, ProductDetails> products = {};

  /// Called right after login in the Play build: listens to Google, and sends any purchase the app did not
  /// finish last time (closed mid-payment, no data) to the server.
  void start() {
    if (_sub != null) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    _iap.isAvailable().then((ok) {
      if (ok) _iap.restorePurchases();
    });
  }

  void dispose() => _sub?.cancel();

  /// Google's own price text for each plan (shown instead of ours in the Play build).
  Future<Map<String, ProductDetails>> load(Iterable<String> ids) async {
    final want = ids.where((i) => i.isNotEmpty).toSet();
    if (want.isEmpty || !await _iap.isAvailable()) return products;
    final r = await _iap.queryProductDetails(want);
    for (final p in r.productDetails) {
      products[p.id] = p;
    }
    return products;
  }

  @override
  bool get takesCodes => false;

  @override
  Future<PayResult> buy(Map<String, dynamic> plan, {String? code, String? channel}) async {
    final id = '${plan['play_product_id'] ?? ''}';
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return const PayFailed('Please log in again.');
    if (id.isEmpty) return const PayFailed('This plan is not ready in Google Play yet. Please try again later.');
    if (!await _iap.isAvailable()) return const PayFailed('Google Play is not available on this phone. Update Google Play and try again.');
    final pd = products[id] ?? (await load([id]))[id];
    if (pd == null) return const PayFailed('This plan is not ready in Google Play yet. Please try again later.');
    final done = Completer<PayResult>();
    _waiting[id] = done;
    final ok = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: pd, applicationUserName: playAccountId(uid)),
      autoConsume: false,
    );
    if (!ok) {
      _waiting.remove(id);
      return const PayFailed('Google Play did not open. Please try again.');
    }
    return done.future;
  }

  @override
  Future<PayResult> check(String reference) async => PayPending(reference);

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      final waiter = _waiting[p.productID];
      if (p.status == PurchaseStatus.pending) {
        // Cash at a shop or a slow bank: Google sends "purchased" later, even after the app restarts.
        _waiting.remove(p.productID);
        if (waiter != null && !waiter.isCompleted) waiter.complete(const PayPending(null));
        continue;
      }
      final result = switch (p.status) {
        PurchaseStatus.canceled => const PayCancelled(),
        PurchaseStatus.error => PayFailed(p.error?.message ?? 'Google Play could not finish the payment.'),
        _ => await _verify(p),
      };
      _waiting.remove(p.productID);
      // Finish (acknowledge) only once our server has given Premium, or when Google says it failed.
      // A purchase the server could not check yet stays open, so it is sent again next time the app starts;
      // Google refunds a purchase that is never acknowledged within 3 days.
      final finish = result is PaySuccess || p.status == PurchaseStatus.canceled || p.status == PurchaseStatus.error;
      if (finish && p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
      if (waiter != null && !waiter.isCompleted) waiter.complete(result);
      if (result is PaySuccess) _onPremium?.call();
    }
  }

  /// Called when a purchase made Premium (also for one finished in the background).
  VoidCallback? _onPremium;
  set onPremium(VoidCallback? f) => _onPremium = f;

  Future<PayResult> _verify(PurchaseDetails p) async {
    try {
      final r = await _sb.functions
          .invoke('play-verify', body: {'productId': p.productID, 'purchaseToken': p.verificationData.serverVerificationData})
          .timeout(const Duration(seconds: 30));
      final d = Map<String, dynamic>.from(r.data as Map);
      return d['status'] == 'success' ? PaySuccess(_date(d['expires_at'])) : const PayPending(null);
    } on FunctionException catch (e) {
      return PayFailed(_fnError(e, 'We could not check this purchase with Google yet. It will be checked again when you reopen the app.'), code: _fnCode(e));
    } catch (_) {
      return const PayPending(null);
    }
  }
}

final playBillingProvider = Provider<PlayBilling>((ref) {
  final b = PlayBilling(ref.read(supabaseProvider));
  ref.onDispose(b.dispose);
  return b;
});

/// The way this build pays.
final paymentProvider = Provider.family<PaymentProvider, bool>(
  (ref, paystack) => paystack ? PaystackProvider(ref.read(supabaseProvider)) : ref.read(playBillingProvider),
);

/// Google's price text per Play product id (empty in the direct build).
final playPricesProvider = FutureProvider<Map<String, String>>((ref) async {
  if (store != Store.play) return const {};
  final plans = await ref.watch(plansForSaleProvider.future);
  try {
    final m = await ref.read(playBillingProvider).load(plans.map((p) => '${p['play_product_id'] ?? ''}'));
    return {for (final e in m.entries) e.key: e.value.price};
  } catch (_) {
    return const {};
  }
});

/// Plans on sale with their Play product ids.
final plansForSaleProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'plans_sale',
    (s) => s
        .from('plans')
        .select('id, code, name, description, price_kobo, duration_days, ends_on, sort, play_product_id')
        .eq('is_active', true)
        .order('sort', ascending: true),
    rows,
  ),
);

// ---------------------------------------------------------------- codes
/// The server's price for a plan with an optional discount code (`quote_price`).
class Quote {
  const Quote({required this.listKobo, required this.discountKobo, required this.amountKobo, this.code, this.label, this.periodEnd});
  final int listKobo, discountKobo, amountKobo;
  final String? code, label;
  final DateTime? periodEnd;
}

/// Friendly text for a code the server refused.
String codeError(String? e, {List<Object?>? plans}) => switch (e) {
  'not_found' => 'We could not find that code. Check the spelling and try again.',
  'expired' => 'This code has expired.',
  'not_started' => 'This code does not work yet.',
  'paused' => 'This code is paused right now.',
  'used_up' => 'This code has been used up.',
  'already_used' => 'You have already used this code.',
  'new_only' => 'This code is only for students who have never paid.',
  'wrong_plan' => plans == null || plans.isEmpty ? 'This code does not work on this plan.' : 'This code only works on the ${plans.join(' or ')} plan.',
  'days_code' => 'This code gives free Premium days. Redeem it in Me, then Redeem a code.',
  'discount_code' => 'This is a discount code. Use it at checkout when you choose a plan.',
  'too_many_tries' => 'Too many wrong codes. Please wait an hour and try again.',
  'covered' => 'Your Premium already covers this plan’s end date.',
  'banned' => 'This account cannot use codes. Contact support.',
  'plan' => 'This plan is not on sale any more. Pick another plan.',
  _ => 'That code cannot be used.',
};

class CodeRepo {
  CodeRepo(this._sb);
  final SupabaseClient _sb;

  /// Throws a [PayFailed] with friendly text when the server refuses.
  Future<Quote> quote(String plan, {String? code}) async {
    final Object? j;
    try {
      j = await _sb.rpc('quote_price', params: {'p_plan': plan, 'p_code': code}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const PayFailed('No internet connection. Check your data or Wi-Fi and try again.');
    }
    final r = Map<String, dynamic>.from(j as Map);
    if (r['ok'] != true) throw PayFailed(codeError(r['error'] as String?, plans: r['plans'] as List?), code: r['error'] as String?);
    return Quote(
      listKobo: (r['list_kobo'] as num).toInt(),
      discountKobo: (r['discount_kobo'] as num).toInt(),
      amountKobo: (r['amount_kobo'] as num).toInt(),
      code: r['code'] as String?,
      label: r['label'] as String?,
      periodEnd: _date(r['period_end']),
    );
  }

  /// Free Premium days. Returns (days, new end date).
  Future<(int, DateTime?)> redeem(String code) async {
    final Object? j;
    try {
      j = await _sb.rpc('redeem_code', params: {'p_code': code}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const PayFailed('No internet connection. Check your data or Wi-Fi and try again.');
    }
    final r = Map<String, dynamic>.from(j as Map);
    if (r['ok'] != true) throw PayFailed(codeError(r['error'] as String?), code: r['error'] as String?);
    return ((r['days'] as num).toInt(), _date(r['expires_at']));
  }
}

final codeRepoProvider = Provider<CodeRepo>((ref) => CodeRepo(ref.read(supabaseProvider)));
