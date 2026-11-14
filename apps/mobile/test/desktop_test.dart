import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/house_ads.dart' show rootNavKey;
import 'package:solutiontee_cbt/core/platform.dart' as plat;
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/desktop/desktop_frame.dart';
import 'package:solutiontee_cbt/features/premium/desktop_pay.dart';
import 'package:solutiontee_cbt/features/premium/payments.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// D-166: the Windows layout and the browser checkout.
class FakePay extends PaystackProvider {
  FakePay() : super(SupabaseClient('http://localhost', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false)), open: (_) async => true);
  PayResult next = const PayPending('st_0123456789abcdef0123');
  int checks = 0;
  final cancels = <String>[];
  @override
  Future<PayResult> check(String reference) async {
    checks++;
    return next;
  }

  @override
  Future<PayResult> cancel(String reference, {String? reason}) async {
    cancels.add(reason ?? '');
    return const PayCancelled();
  }
}

void main() {
  test('desktop is decided by the target platform (phone tests stay phone)', () {
    expect(plat.isDesktop, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(plat.isDesktop, isTrue);
    expect(plat.isWindows, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  test('one account per computer: hardware id cleaned, placeholders and virtual machines spotted', () {
    expect(plat.DesktopMachine.cleanHardwareId('{4C4C4544-0042-3510-8051-B4C04F384E32}'), '4c4c4544-0042-3510-8051-b4c04f384e32');
    expect(plat.DesktopMachine.cleanHardwareId('{00000000-0000-0000-0000-000000000000}'), isNull);
    expect(plat.DesktopMachine.cleanHardwareId('FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'), isNull);
    expect(plat.DesktopMachine.cleanHardwareId('{03000200-0400-0500-0006-000700080009}'), isNull);
    expect(plat.DesktopMachine.cleanHardwareId('not a uuid'), isNull);
    expect(plat.DesktopMachine.cleanHardwareId(null), isNull);
    expect(plat.DesktopMachine.isVirtualMachine('innotek GmbH VirtualBox'), isTrue);
    expect(plat.DesktopMachine.isVirtualMachine('VMware, Inc. VMware7,1'), isTrue);
    expect(plat.DesktopMachine.isVirtualMachine('Microsoft Corporation Virtual Machine'), isTrue);
    expect(plat.DesktopMachine.isVirtualMachine('HP HP Laptop 15-dw3xxx'), isFalse);
    expect(plat.DesktopMachine.isVirtualMachine('Dell Inc. Latitude 5420'), isFalse);
  });

  test('routes: sidebar pages, focus pages (exams, games) and sign-in pages', () {
    expect(desktopModeFor('/home'), DesktopMode.normal);
    expect(desktopModeFor('/settings'), DesktopMode.normal);
    expect(desktopModeFor('/cbt/abc'), DesktopMode.focus);
    expect(desktopModeFor('/challenges/1/play'), DesktopMode.focus);
    expect(desktopModeFor('/test/challenges/1/mock'), DesktopMode.focus);
    expect(desktopModeFor('/games/play/7'), DesktopMode.focus);
    expect(desktopModeFor('/login'), DesktopMode.auth);
    expect(desktopModeFor('/setup'), DesktopMode.auth);
    expect(desktopModeFor('/splash'), DesktopMode.focus);
  });

  test('page widths: dashboards wide, lists medium, reading narrow, games a stage', () {
    expect(desktopWidthFor('/home', DesktopMode.normal), 1280);
    expect(desktopWidthFor('/study/videos', DesktopMode.normal), 1280);
    expect(desktopWidthFor('/leaderboard', DesktopMode.normal), 980);
    expect(desktopWidthFor('/community', DesktopMode.normal), 820);
    expect(desktopWidthFor('/news/12', DesktopMode.normal), 860);
    expect(desktopWidthFor('/settings', DesktopMode.normal), 860);
    expect(desktopWidthFor('/games', DesktopMode.normal), 620);
    expect(desktopWidthFor('/games/play/1', DesktopMode.focus), 620);
    expect(desktopWidthFor('/cbt/1', DesktopMode.focus), double.infinity);
    expect(desktopWidthFor('/login', DesktopMode.auth), 560);
  });

  Widget frame(String start, {Size size = const Size(1440, 900)}) {
    final router = GoRouter(
      initialLocation: start,
      navigatorKey: rootNavKey,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME PAGE')),
        ),
        GoRoute(
          path: '/study',
          builder: (_, _) => const Scaffold(body: Text('STUDY PAGE')),
        ),
        GoRoute(
          path: '/cbt/:id',
          builder: (_, _) => const Scaffold(body: Text('EXAM')),
        ),
        GoRoute(
          path: '/search',
          builder: (_, _) => const Scaffold(body: Text('SEARCH PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
        myPlanProvider.overrideWith((_) async => {'tier': 'free'}),
        myStreakProvider.overrideWith((_) async => {'current': 4}),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        routerConfig: router,
        builder: (context, child) => DesktopFrame(router: router, child: child!),
      ),
    );
  }

  testWidgets('the sidebar shows on normal pages and navigates; exams open without it', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(frame('/home'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('HOME PAGE'), findsOneWidget);
    expect(find.byType(DesktopSidebar), findsOneWidget);
    expect(find.text('Ada Obi'), findsOneWidget);
    await t.tap(find.text('Study'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('STUDY PAGE'), findsOneWidget);

    await t.pumpWidget(frame('/cbt/1'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('EXAM'), findsOneWidget);
    expect(find.byType(DesktopSidebar), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a narrow (snapped) window falls back to the phone layout', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    t.view.physicalSize = const Size(700, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(frame('/home'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(DesktopSidebar), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('browser checkout: waits, then closes by itself when the server confirms', (t) async {
    final pay = FakePay();
    PayResult? got;
    final opened = <Uri>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              got = await Navigator.of(context).push<PayResult>(
                MaterialPageRoute(
                  builder: (_) => DesktopPayScreen(
                    w: PayWeb('st_0123456789abcdef0123', Uri.parse('https://checkout.paystack.com/abc')),
                    pay: pay,
                    what: 'Premium · 3 months',
                    openBrowser: (u) async {
                      opened.add(u);
                      return true;
                    },
                  ),
                ),
              );
            },
            child: const Text('PAY'),
          ),
        ),
      ),
    );
    await t.tap(find.text('PAY'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Finish paying in your browser'), findsOneWidget);
    expect(opened.single.host, 'checkout.paystack.com');
    await t.pump(const Duration(seconds: 3));
    expect(pay.checks, 1);
    expect(got, isNull);
    pay.next = PaySuccess(DateTime(2027));
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 1)); // the page closes (transition)
    expect(got, isA<PaySuccess>());
    expect(find.text('Finish paying in your browser'), findsNothing);
  });

  testWidgets('browser checkout: Cancel payment asks, then cancels on the server', (t) async {
    final pay = FakePay();
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: DesktopPayScreen(
          w: PayWeb('st_0123456789abcdef0123', Uri.parse('https://checkout.paystack.com/abc')),
          pay: pay,
          what: 'Premium',
          openBrowser: (_) async => true,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Cancel payment'));
    await t.pump(const Duration(milliseconds: 400));
    // The same "Leave this payment?" sheet the phone uses; choose to leave.
    expect(find.text('Leave this payment?'), findsOneWidget);
    await t.tap(find.text('Leave and cancel payment'));
    await t.pump(const Duration(milliseconds: 600));
    expect(pay.cancels, ['left the desktop checkout']);
  });
}
