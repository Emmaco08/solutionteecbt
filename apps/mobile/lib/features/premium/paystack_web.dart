import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'pay_ui.dart';
import 'payments.dart';

/// What to do with a page the checkout wants to open (D-093). Kept apart so it can be tested.
enum WebNav { stay, closeAndCheck, cancel, openApp }

WebNav paystackNav(Uri u) {
  if (u.scheme != 'http' && u.scheme != 'https') return WebNav.openApp; // intent://, opay://, tel:, … open the real app
  if (u.host == 'standard.paystack.co' && u.path.startsWith('/close')) return WebNav.cancel; // Paystack's own "close"
  if (u.path.startsWith('/pay/done')) return WebNav.closeAndCheck; // our callback page: Paystack says it is done
  return WebNav.stay;
}

/// Android "intent://…#Intent;scheme=opay;package=…;S.browser_fallback_url=…;end" links, made openable:
/// first the app's own link (scheme), then the page's fallback, then the app in the Play Store.
List<Uri> intentTargets(Uri u) {
  final raw = u.toString();
  if (!raw.startsWith('intent:')) return [u];
  final hash = raw.indexOf('#Intent;');
  final body = raw.substring('intent:'.length, hash < 0 ? raw.length : hash);
  final parts = hash < 0 ? const <String>[] : raw.substring(hash + 8).split(';');
  String? scheme, pkg, fallback;
  for (final p in parts) {
    if (p.startsWith('scheme=')) scheme = p.substring(7);
    if (p.startsWith('package=')) pkg = p.substring(8);
    if (p.startsWith('S.browser_fallback_url=')) fallback = Uri.decodeComponent(p.substring(23));
  }
  return [
    if (scheme != null) ?Uri.tryParse('$scheme:$body'),
    if (fallback != null && fallback.startsWith('https://')) ?Uri.tryParse(fallback),
    if (pkg != null) Uri.parse('market://details?id=$pkg'),
  ];
}

Future<void> openOutside(Uri u) async {
  for (final t in intentTargets(u)) {
    try {
      if (await launchUrl(t, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
  }
}

/// Paystack's web checkout inside our own screen: OPay, PocketApp, Zap and bank apps are only offered there.
/// Our top bar and back button, a "Secured by Paystack" strip, a loading bar, and a check every 4 seconds
/// that closes the screen as soon as the server confirms the payment. Links to bank / wallet apps open the app.
Future<PayResult?> showPaystackWeb(BuildContext context, PayWeb w, PaystackProvider pay, {required String what, String? via}) =>
    Navigator.of(context, rootNavigator: true).push<PayResult>(
      MaterialPageRoute(
        builder: (_) => PaystackWebScreen(w: w, pay: pay, what: what, via: via),
      ),
    );

/// Paystack's checkout has no link that opens it on OPay / Zap / Bank directly, so once it has loaded we tap that
/// option for the student (behind our own "Opening OPay…" cover). [via] is the name we look for ("OPay", "Zap",
/// "PocketApp", "Bank"); the row text may be "Pay with OPay" or "NEW Pay with Zap". The script tells the app through
/// the `StApp` channel: "clicked" or "notfound" (then the cover lifts and a hint says what to tap).
String autoTapScript(String via) {
  final name = via.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return '''
(function () {
  var re = new RegExp('(^| )(pay with +)?$name *\$', 'i'); // spaces: the text is squashed to single spaces below
  var tries = 0;
  function text(e) { return (e.innerText || '').replace(/\\s+/g, ' ').trim(); }
  function tap() {
    // Tap the link or button itself: Paystack listens on the <a> inside each <li class="nav__item">,
    // and a tap on the outer <li> never reaches it (phone test, 2026-11-04).
    var hits = document.querySelectorAll('a, button, [role="button"]');
    for (var i = 0; i < hits.length; i++) {
      var t = text(hits[i]);
      if (t.length > 0 && t.length < 40 && re.test(t)) { hits[i].click(); return true; }
    }
    // Fallback: a row without a link: tap the clickable thing inside it, else the row.
    var rows = document.querySelectorAll('li, div, span');
    for (var j = 0; j < rows.length; j++) {
      var u = text(rows[j]);
      if (u.length > 0 && u.length < 40 && re.test(u)) {
        (rows[j].querySelector('a, button, [role="button"]') || rows[j]).click();
        return true;
      }
    }
    return false;
  }
  var timer = setInterval(function () {
    tries++;
    if (tap()) { clearInterval(timer); StApp.postMessage('clicked'); }
    else if (tries > 40) { clearInterval(timer); StApp.postMessage('notfound'); }
  }, 250);
})();
''';
}

class PaystackWebScreen extends StatefulWidget {
  const PaystackWebScreen({super.key, required this.w, required this.pay, required this.what, this.via, this.controller});
  final PayWeb w;
  final PaystackProvider pay;
  final String what;

  /// "OPay", "Zap", …: what to tap on Paystack's page.
  final String? via;

  /// For tests.
  final WebViewController? controller;
  @override
  State<PaystackWebScreen> createState() => _PaystackWebScreenState();
}

class _PaystackWebScreenState extends State<PaystackWebScreen> with WidgetsBindingObserver {
  WebViewController? _web;
  int _progress = 0;
  bool _failed = false, _checking = false, _done = false, _leaving = false, _asking = false;
  // Our cover over Paystack's list while we open the chosen option; the hint shows only if it could not be found.
  bool _covered = false, _tapped = false, _hint = false, _ready = false;
  Timer? _poll, _coverTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _covered = widget.via != null;
    _web = widget.controller ?? _make();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    // Never leave the student behind the cover: lift it after 10 s whatever happens.
    if (_covered) _coverTimeout = Timer(const Duration(seconds: 10), () => _uncover(hint: true));
  }

  WebViewController? _make() {
    try {
      return WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel(
          'StApp',
          onMessageReceived: (m) {
            if (m.message == 'clicked') {
              // Show the tick, let Paystack draw the OPay / Zap / Bank step, then lift the cover.
              if (mounted) setState(() => _ready = true);
              Future<void>.delayed(const Duration(milliseconds: 1100), () => _uncover());
            } else {
              _uncover(hint: true);
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) => mounted ? setState(() => _progress = p) : null,
            onPageFinished: (url) {
              final via = widget.via;
              if (via == null || _tapped || Uri.tryParse(url)?.host != 'checkout.paystack.com') return;
              _tapped = true;
              _web?.runJavaScript(autoTapScript(via)).catchError((_) => _uncover(hint: true));
            },
            onPageStarted: (_) => mounted ? setState(() => _failed = false) : null,
            onWebResourceError: (e) {
              if (e.isForMainFrame == true && mounted) setState(() => _failed = true);
            },
            onNavigationRequest: (req) {
              final u = Uri.tryParse(req.url);
              if (u == null) return NavigationDecision.prevent;
              switch (paystackNav(u)) {
                case WebNav.openApp:
                  openOutside(u);
                  return NavigationDecision.prevent;
                case WebNav.cancel:
                  // Paystack's own "Cancel payment": no need to ask again.
                  _leave(reason: 'cancelled on Paystack\'s page');
                  return NavigationDecision.prevent;
                case WebNav.closeAndCheck:
                  _check(finish: true);
                  return NavigationDecision.prevent;
                case WebNav.stay:
                  return NavigationDecision.navigate;
              }
            },
          ),
        )
        ..loadRequest(widget.w.url);
    } catch (_) {
      return null; // no WebView on this phone: the in-app tab below is used instead
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _coverTimeout?.cancel();
    super.dispose();
  }

  // Back from the OPay / bank app: check at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool finish = false}) async {
    if (_checking || _done || !mounted) return;
    _checking = true;
    final r = await widget.pay.check(widget.w.reference);
    _checking = false;
    if (!mounted || _done) return;
    if (r is PaySuccess || (r is PayFailed && r.code == 'review')) {
      _done = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(r);
    } else if (finish) {
      // Paystack finished but the money is not confirmed yet (transfers can take a minute): leave, keep checking outside.
      _done = true;
      Navigator.of(context).pop(PayPending(widget.w.reference));
    }
  }

  /// Back or our back arrow: ask first (D-095). Stay → nothing; I have paid → check now; Leave → cancel on the server.
  Future<void> _confirmLeave() async {
    if (_done || _asking || _leaving || !mounted) return;
    _asking = true;
    final choice = await confirmLeavePayment(context, via: widget.via, what: widget.what);
    _asking = false;
    if (!mounted || _done) return;
    switch (choice) {
      case LeaveChoice.stay:
        break;
      case LeaveChoice.paid:
        await _check(finish: true);
      case LeaveChoice.leave:
        await _leave(reason: 'pressed back');
    }
  }

  /// Cancel on the server (it asks Paystack first, so a payment made in the OPay app still counts), then close.
  Future<void> _leave({required String reason}) async {
    if (_done || _leaving || !mounted) return;
    setState(() => _leaving = true);
    final r = await widget.pay.cancel(widget.w.reference, reason: reason).timeout(const Duration(seconds: 10), onTimeout: () => const PayCancelled());
    if (!mounted || _done) return;
    _done = true;
    if (r is PaySuccess) HapticFeedback.mediumImpact();
    Navigator.of(context).pop(r);
  }

  void _uncover({bool hint = false}) {
    _coverTimeout?.cancel();
    if (!mounted || !_covered) return;
    setState(() => (_covered = false, _hint = hint));
    if (hint) Timer(const Duration(seconds: 7), () => mounted ? setState(() => _hint = false) : null);
  }

  Future<void> _openTab() async {
    await launchUrl(widget.w.url, mode: LaunchMode.inAppBrowserView).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final web = _web;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Inside a bank's own page (for example a card check), back goes back there; on Paystack's checkout we ask.
        if (web != null && await web.canGoBack() && Uri.tryParse(await web.currentUrl() ?? '')?.host != 'checkout.paystack.com') return web.goBack();
        _confirmLeave();
      },
      child: Scaffold(
        appBar: TopBar(title: widget.via == null ? 'Pay' : 'Pay with ${widget.via}', onBack: _confirmLeave),
        body: Column(
          children: [
            AnimatedOpacity(
              opacity: _progress < 100 && !_failed ? 1 : 0,
              duration: rm ? Duration.zero : Motion.fast,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100,
                minHeight: 3,
                color: c.secondary,
                backgroundColor: c.surfaceSunken,
              ),
            ),
            Expanded(
              child: web == null || _failed
                  ? _Problem(
                      offline: _failed,
                      onRetry: web == null
                          ? _openTab
                          : () {
                              setState(() => _failed = false);
                              web.loadRequest(widget.w.url);
                            },
                      onTab: _openTab,
                    )
                  : Stack(
                      children: [
                        WebViewWidget(controller: web),
                        if (_hint && widget.via != null)
                          Positioned(
                            top: Space.s3,
                            left: Space.s5,
                            right: Space.s5,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                                  decoration: BoxDecoration(color: Palette.navy900, borderRadius: BorderRadius.circular(99), boxShadow: context.shadow(3)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(PhosphorIcons.handTap(PhosphorIconsStyle.fill), size: 18, color: Palette.gold400),
                                      const Gap(Space.s2),
                                      Flexible(
                                        child: Text(
                                          '${widget.via} is not offered right now. Choose another way below.',
                                          style: context.ty.sm.bold.col(Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: rm ? 1.ms : 250.ms).slideY(begin: rm ? 0 : -.4, end: 0, curve: Curves.easeOutBack),
                        if (widget.via != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: !_covered,
                              child: AnimatedSwitcher(
                                duration: rm ? Duration.zero : const Duration(milliseconds: 420),
                                switchOutCurve: Curves.easeIn,
                                child: _covered
                                    ? PayOpeningCover(
                                        key: const ValueKey('cover'),
                                        via: widget.via!,
                                        what: widget.what,
                                        loaded: _progress >= 100 || _tapped,
                                        ready: _ready,
                                        still: rm,
                                      )
                                    : const SizedBox.shrink(key: ValueKey('none')),
                              ),
                            ),
                          ),
                        if (_leaving) const Positioned.fill(child: PayBusyVeil(text: 'Cancelling payment…')),
                      ],
                    ),
            ),
            // Always-there way out + status
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s2),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.secondary)),
                    const Gap(Space.s2),
                    Expanded(child: Text('We add it the moment Paystack confirms.', style: context.ty.cap.col(c.textMuted))),
                    TextButton(onPressed: () => _check(finish: true), child: const Text('I have paid')),
                  ],
                ),
              ).animate().fadeIn(duration: rm ? 1.ms : 300.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.offline, required this.onRetry, required this.onTab});
  final bool offline;
  final VoidCallback onRetry, onTab;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.s6),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTile(PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill), tone: Tone.navy, size: 56, radius: 16, iconSize: 28),
        const Gap(Space.s4),
        Text(offline ? 'Paystack did not load' : 'This phone cannot show the payment page here', style: context.ty.h3, textAlign: TextAlign.center),
        const Gap(Space.s2),
        Text('Check your internet, then try again. You will not be charged twice.', style: context.ty.sm.col(context.c.textMuted), textAlign: TextAlign.center),
        const Gap(Space.s4),
        Btn('Try again', onPressed: onRetry),
        const Gap(Space.s2),
        Btn('Open in a secure tab', kind: BtnKind.ghost, onPressed: onTab),
      ],
    ),
  );
}
