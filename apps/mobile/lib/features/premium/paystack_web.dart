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
  bool _failed = false, _checking = false, _done = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web = widget.controller ?? _make();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  WebViewController? _make() {
    try {
      return WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) => mounted ? setState(() => _progress = p) : null,
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
                  _close();
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

  void _close() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop();
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
        if (web != null && await web.canGoBack()) return web.goBack();
        _close();
      },
      child: Scaffold(
        appBar: TopBar(title: widget.via == null ? 'Pay' : 'Pay with ${widget.via}', onBack: _close),
        body: Column(
          children: [
            // Secure strip + what is being paid for
            Container(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s2),
              color: c.surfaceAlt,
              child: Row(
                children: [
                  Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 16, color: c.success),
                  const Gap(Space.s2),
                  Expanded(
                    child: Text(
                      '${widget.what} · secured by Paystack${widget.via == null ? '' : ' · tap ${widget.via} below'}',
                      style: context.ty.cap.col(c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
                  : WebViewWidget(controller: web),
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
