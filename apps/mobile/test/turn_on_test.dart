import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/push.dart';
import 'package:solutiontee_cbt/features/notifications/turn_on_sheet.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  const ch = MethodChannel('solutiontee/notify');
  final calls = <String>[];
  var on = false;

  setUp(() {
    calls.clear();
    on = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (m) async {
      calls.add(m.method);
      return switch (m.method) {
        'enabled' => on,
        'sdk' => 34,
        _ => true,
      };
    });
  });

  testWidgets('"Turn on notifications" opens the phone settings; "Not now" closes', (t) async {
    late WidgetRef r;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Consumer(
            builder: (c, ref, _) {
              r = ref;
              return Scaffold(
                body: TextButton(onPressed: () => showTurnOnNotifications(c, r), child: const Text('open')),
              );
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Turn on notifications'), findsOneWidget);
    await t.tap(find.text('Turn on'));
    await t.pumpAndSettle();
    expect(calls, contains('openSettings'));
    expect(find.text('Turn on notifications'), findsNothing);

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(find.text('Turn on notifications'), findsNothing);
  });

  testWidgets('Settings banner shows only while notifications are off', (t) async {
    Future<void> pump() async {
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: NotificationsOffBanner()),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await pump();
    expect(find.text('Notifications are off on this phone.'), findsOneWidget);
    on = true;
    await t.pumpWidget(const SizedBox());
    await pump();
    expect(find.text('Notifications are off on this phone.'), findsNothing);
  });

  test('the on/off check asks Android', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(pushProvider).enabled(), isFalse);
    on = true;
    expect(await c.read(pushProvider).enabled(), isTrue);
  });
}
