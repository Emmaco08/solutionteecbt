import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show MethodChannel, appFlavor;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';

/// Which shop this build sells through (D-061). Set at build time with `--flavor direct|play`.
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

/// The same, for button handlers and other code outside build (reads, does not watch).
bool usesPaystackNow(WidgetRef ref) => store == Store.direct || (ref.read(featureFlagsProvider).value?['paystack_in_play_build'] ?? false);

/// "Redeem a code" (free Premium days): always in the direct build; in the Play build only with `codes_in_play_build`.
bool showsRedeem(WidgetRef ref) => store == Store.direct || (ref.watch(featureFlagsProvider).value?['codes_in_play_build'] ?? false);

/// Payment settings chosen by the admin (D-113): which ways the Play app offers (Google Play, the payment website, or
/// both) and whether processing fees are added (Paystack: added to the price; Google: the plan's second Play product).
class PaySettings {
  const PaySettings(this.j);
  final Map<String, dynamic> j;
  Map<String, dynamic> _m(Object? o) => o is Map ? Map<String, dynamic>.from(o) : const {};
  Map<String, dynamic> get _play => _m(j['play']);
  Map<String, dynamic> get _fees => _m(j['fees']);

  /// The payment website is offered in the Play app.
  bool get playWebsite => _play['website'] == true;

  /// Google Play Billing in the Play app (never both off: then Google stays on).
  bool get playGoogle => _play['google'] != false || !playWebsite;
  String get websiteUrl => '${j['website_url'] ?? ''}'.startsWith('https://') ? '${j['website_url']}' : 'https://cbt.solutiontee.com/pay';
  bool get googleFee => _m(_fees['google'])['on'] == true;

  /// The Paystack processing fee for an amount, the same sum as the server's `private.paystack_fee` (display only:
  /// the server always works out what is charged).
  int paystackFeeKobo(int amountKobo) {
    final f = _m(_fees['paystack']);
    if (f['on'] != true || amountKobo <= 0) return 0;
    double n(String k, double d) => (f[k] as num?)?.toDouble() ?? d;
    final pct = n('pct', 1.5).clamp(0, 20) / 100;
    final flat = n('flat', 0) * 100, from = n('flat_from', 0) * 100, cap = n('cap', 0) * 100;
    var total = amountKobo / (1 - pct);
    if (flat > 0 && total >= from) total = (amountKobo + flat) / (1 - pct);
    var fee = ((total - amountKobo) / 100).ceil() * 100;
    if (cap > 0 && fee > cap) fee = cap.toInt();
    return fee < 0 ? 0 : fee;
  }
}

final paySettingsProvider = Provider<PaySettings>((ref) {
  final s = ref.watch(appSettingsProvider).value?['payments'];
  return PaySettings(s is Map ? Map<String, dynamic>.from(s) : const {});
});

/// Opens the payment website in the browser (Play app, when the admin offers it). The plan is pre-chosen, and a
/// one-time code logs the student in there (D-115); without it (offline, old website) they log in with their email.
Future<bool> openPayWebsite(WidgetRef ref, {String? plan}) async {
  final base = Uri.parse(ref.read(paySettingsProvider).websiteUrl);
  String? code;
  try {
    code = await ref.read(apiProvider).webHandoff(plan: plan).timeout(const Duration(seconds: 8));
  } catch (_) {}
  final email = code == null ? Supabase.instance.client.auth.currentUser?.email : null;
  final uri = base.replace(queryParameters: {...base.queryParameters, 'plan': ?plan, 'h': ?code, 'email': ?email, 'from': 'app'});
  return launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
}

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

/// Pay by bank transfer or USSD on our own screen (D-089): the account to send to, or the code to dial.
class PayOffline extends PayResult {
  const PayOffline(this.reference, {required this.amountKobo, this.transfer, this.ussd});
  final String reference;
  final int amountKobo;

  /// {account_number, account_name, bank, expires_at}
  final Map<String, dynamic>? transfer;

  /// {code, bank}
  final Map<String, dynamic>? ussd;
}

/// Pay inside Paystack's web checkout, embedded in our own screen (D-093): OPay, PocketApp, Zap and bank apps
/// are only offered there, not in Paystack's card sheet.
class PayWeb extends PayResult {
  const PayWeb(this.reference, this.url);
  final String reference;
  final Uri url;
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
/// Paystack's own payment sheet inside the app (android/app/src/direct/…/PaystackBridge.kt). Replaced in tests.
class PaystackSheet {
  const PaystackSheet();
  static const _ch = MethodChannel('solutiontee/paystack');

  Future<bool> available() async {
    try {
      return await _ch.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// {status: success|cancelled|failed|unavailable|busy|unknown, reference?, message?}
  Future<Map<String, dynamic>> launch({required String publicKey, required String accessCode, bool dark = false}) async {
    try {
      final r = await _ch.invokeMethod<Map<Object?, Object?>>('launch', {'publicKey': publicKey, 'accessCode': accessCode, 'dark': dark});
      return {for (final e in (r ?? const {}).entries) '${e.key}': e.value};
    } catch (_) {
      return {'status': 'unavailable'};
    }
  }
}

/// The ways to pay with Paystack (D-089, D-092). USSD needs the student's bank. OPay, PocketApp, Zap and bank apps
/// (Kuda, PalmPay) are only offered inside Paystack's own secure screen, so they open it ("page") inside the app.
enum PayMethod { card, transfer, ussd, opay, pocketapp, zap, bankApp }

extension PayMethodText on PayMethod {
  /// For "Pay ₦3,500 with …".
  String get withText => switch (this) {
    PayMethod.card => 'with card',
    PayMethod.transfer => 'by transfer',
    PayMethod.ussd => 'with USSD',
    PayMethod.opay => 'with OPay',
    PayMethod.pocketapp => 'with PocketApp',
    PayMethod.zap => 'with Zap',
    PayMethod.bankApp => 'with your bank app',
  };

  /// What to tap on Paystack's page, e.g. "OPay" (null for our own screens and the card form).
  String? get viaName => switch (this) {
    PayMethod.opay => 'OPay',
    PayMethod.pocketapp => 'PocketApp',
    PayMethod.zap => 'Zap',
    PayMethod.bankApp => 'Bank',
    _ => null,
  };

  /// Opens Paystack's own screen (where this app is chosen) instead of our screen or the card form.
  bool get inPaystackScreen => this == PayMethod.opay || this == PayMethod.pocketapp || this == PayMethod.zap || this == PayMethod.bankApp;
}

const ussdBanks = {'737': 'GTBank', '919': 'UBA', '822': 'Sterling Bank', '966': 'Zenith Bank'};

class PaystackProvider implements PaymentProvider {
  PaystackProvider(this._sb, {this.open = _openTab, this.sheet = const PaystackSheet()});
  final SupabaseClient _sb;

  /// Opens Paystack's checkout page (when the in-app sheet cannot be used). Replaced in tests.
  final Future<bool> Function(Uri) open;
  final PaystackSheet sheet;

  /// Paystack's sheet follows the app's light or dark look; the screen sets this before paying.
  bool dark = false;

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

  /// "card", "transfer" or "ussd:737" (the [channel] of [buy]) → what the server needs.
  static Map<String, Object?> methodBody(String? channel) {
    final c = channel ?? 'card';
    if (c.startsWith('ussd')) return {'method': 'ussd', 'bank': c.contains(':') ? c.split(':')[1] : '737'};
    return {'method': c == 'transfer' || c == 'page' ? c : 'card'};
  }

  /// What the server answered → what the student sees next: Paystack's sheet (card), our transfer / USSD screen,
  /// or Paystack's page in an in-app tab when the sheet is not available.
  @visibleForTesting
  Future<PayResult> openResult(Map<String, dynamic> r, {bool web = false}) async {
    final reference = '${r['reference'] ?? ''}';
    if (web) {
      final u = Uri.tryParse('${r['url'] ?? ''}');
      return u != null && u.isScheme('https') ? PayWeb(reference, u) : const PayFailed('Paystack did not open. Please try again.');
    }
    final amount = (r['amount_kobo'] as num?)?.toInt() ?? 0;
    if (r['transfer'] is Map) return PayOffline(reference, amountKobo: amount, transfer: Map<String, dynamic>.from(r['transfer'] as Map));
    if (r['ussd'] is Map) return PayOffline(reference, amountKobo: amount, ussd: Map<String, dynamic>.from(r['ussd'] as Map));
    final pk = r['public_key'], code = r['access_code'];
    if (pk is String && pk.isNotEmpty && code is String && code.isNotEmpty && await sheet.available()) {
      final s = await sheet.launch(publicKey: pk, accessCode: code, dark: dark);
      switch (s['status']) {
        case 'success':
          // Paystack says paid: confirm with the server (verify), which gives Premium or XP.
          final c = await check(reference);
          return c is PayFailed && c.code != 'review' ? PayPending(reference) : c;
        case 'cancelled':
          // Closed Paystack's sheet: tell the server now, so the admin page does not show it waiting (D-095).
          return await cancel(reference, reason: 'closed the card sheet');
        case 'failed':
          final m = '${s['message'] ?? ''}'.trim();
          return PayFailed(m.isEmpty ? 'The payment did not go through. You were not charged. Try again or use another way to pay.' : m);
        case 'unknown':
          return PayPending(reference);
        default:
          break; // unavailable or busy: use the page instead
      }
    }
    final url = Uri.tryParse('${r['url'] ?? ''}');
    if (url == null || !url.isScheme('https')) return const PayFailed('Paystack did not open. Please try again.');
    final opened = await open(url);
    if (!opened) return const PayFailed('Could not open Paystack on this phone. Please try again.');
    return PayPending(reference);
  }

  @override
  Future<PayResult> buy(Map<String, dynamic> plan, {String? code, String? channel}) async {
    try {
      final r = await _call({
        'action': 'start',
        'plan': plan['code'],
        if (code != null && code.isNotEmpty) 'code': code,
        'source': 'app',
        ...methodBody(channel),
      });
      if (r['free'] == true) return PaySuccess(_date(r['expires_at']), free: true);
      return await openResult(r, web: channel == 'page');
    } on PayFailed catch (e) {
      return e;
    }
  }

  /// One study item or exam year (D-106): the server sets the price from the admin's settings; yours for good.
  Future<PayResult> buyItem(String kind, String itemRef, {String? channel}) async {
    try {
      return await openResult(
        await _call({'action': 'start_item', 'kind': kind, 'ref': itemRef, 'source': 'app', ...methodBody(channel)}),
        web: channel == 'page',
      );
    } on PayFailed catch (e) {
      return e;
    }
  }

  /// An XP pack (D-084): the server sets the price from the admin's packs; paid like a plan.
  Future<PayResult> buyXp(int xp, {String? channel}) async {
    try {
      return await openResult(await _call({'action': 'start_xp', 'xp': xp, 'source': 'app', ...methodBody(channel)}), web: channel == 'page');
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
        'abandoned' => const PayCancelled(),
        _ => PayPending(reference),
      };
    } on PayFailed catch (e) {
      return e;
    }
  }

  /// The student left or cancelled before paying (D-095). The server asks Paystack first: if it was paid after all
  /// (for example in the OPay app) Premium / XP is given and this returns [PaySuccess]; otherwise the payment is
  /// marked "Not finished" and this returns [PayCancelled]. Never throws; with no internet it still returns
  /// [PayCancelled] (the payment then ends as "Not finished" after a day, and a late success still counts).
  Future<PayResult> cancel(String reference, {String? reason}) async {
    if (reference.isEmpty) return const PayCancelled();
    try {
      final r = await _call({'action': 'cancel', 'reference': reference, 'reason': ?reason});
      return switch (r['status']) {
        'success' => PaySuccess(_date(r['expires_at'])),
        'needs_review' => const PayFailed(
          'We are checking this payment. If you were charged, Premium turns on after our check, or contact support.',
          code: 'review',
        ),
        _ => const PayCancelled(),
      };
    } on PayFailed {
      return const PayCancelled();
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

/// Plans on sale with their Play product ids. With the Google fee on (D-113), each plan uses its second Play product
/// (priced with the fee in Play Console) when it has one.
final plansForSaleProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final fee = ref.watch(paySettingsProvider).googleFee;
  final list = await cached(
    ref,
    'plans_sale',
    (s) => s
        .from('plans')
        .select('id, code, name, description, price_kobo, duration_days, ends_on, sort, play_product_id, play_product_id_fee')
        .eq('is_active', true)
        .order('sort', ascending: true),
    rows,
  );
  if (!fee) return list;
  return [
    for (final p in list) {...p, if ('${p['play_product_id_fee'] ?? ''}'.isNotEmpty) 'play_product_id': p['play_product_id_fee']},
  ];
});

// ---------------------------------------------------------------- codes
/// The server's price for a plan with an optional discount code (`quote_price`).
class Quote {
  const Quote({required this.listKobo, required this.discountKobo, required this.amountKobo, this.feeKobo = 0, this.code, this.label, this.periodEnd});

  /// [feeKobo]: the processing fee the admin chose to add (already inside [amountKobo]).
  final int listKobo, discountKobo, amountKobo, feeKobo;
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
      feeKobo: (r['fee_kobo'] as num?)?.toInt() ?? 0,
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
