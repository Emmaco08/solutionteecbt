import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/desktop_alerts.dart';
import 'package:solutiontee_cbt/data/notifications_repo.dart';

/// D-166: live notifications on Windows come from the inbox, not Firebase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('test/desktop');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, dynamic> row(String id, {String topic = 'announcements', bool read = false, Map<String, dynamic>? link}) => {
    'id': id,
    'topic': topic,
    'title': 'Title $id',
    'body': 'Body $id',
    'link': link ?? const {},
    'sent_at': DateTime.now().toUtc().toIso8601String(),
    'read': read,
  };

  late List<Map<String, dynamic>> inbox;
  late List<Map<String, Object?>> native;
  late bool behind;
  late List<String> toasts;
  late List<List<String>> opened;

  (ProviderContainer, DesktopAlerts) make({Map<String, bool> prefs = const {}}) {
    final c = ProviderContainer(
      overrides: [
        notificationPrefsProvider.overrideWith((_) async => prefs),
        notificationsProvider.overrideWith((_) async => const []),
        desktopAlertsProvider.overrideWith((ref) => DesktopAlerts(ref, channel: ch, fetch: () async => [...inbox])),
      ],
    );
    final a = c.read(desktopAlertsProvider)
      ..onForeground = toasts.add
      ..onOpen = ((id, type, target) => opened.add([id, type, target]));
    return (c, a);
  }

  setUp(() {
    inbox = [row('n1'), row('n0', read: true)];
    native = [];
    behind = false;
    toasts = [];
    opened = [];
    messenger.setMockMethodCallHandler(ch, (call) async {
      native.add({'method': call.method, ...Map<String, Object?>.from(call.arguments as Map)});
      return behind;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(ch, null));

  test('what is already in the inbox when the app opens is not announced', () async {
    final (c, a) = make();
    await a.poll();
    await a.poll();
    expect(toasts, isEmpty);
    expect(native, isEmpty);
    c.dispose();
  });

  test('a new message: in-app toast when the window is in front', () async {
    final (c, a) = make();
    await a.poll();
    inbox.insert(0, row('n2'));
    await a.poll();
    expect(native.single['title'], 'Title n2');
    expect(toasts, ['Title n2']);
    await a.poll(); // not announced twice
    expect(toasts.length, 1);
    c.dispose();
  });

  test('window behind: a Windows notification instead of the toast', () async {
    final (c, a) = make();
    await a.poll();
    behind = true;
    inbox.insert(0, row('n2'));
    await a.poll();
    expect(native.single, containsPair('id', 'n2'));
    expect(native.single, containsPair('body', 'Body n2'));
    expect(toasts, isEmpty);
    c.dispose();
  });

  test('several at once are grouped; switched-off topics stay quiet', () async {
    final (c, a) = make(prefs: {'streak': false});
    await a.poll();
    inbox.insertAll(0, [row('n4'), row('n3'), row('s1', topic: 'streak')]);
    await a.poll();
    expect(toasts, ['2 new messages']);
    expect(native.single['body'], 'Title n4 · Title n3');
    inbox.insert(0, row('s2', topic: 'streak'));
    await a.poll();
    expect(toasts.length, 1);
    c.dispose();
  });

  test('clicking the Windows notification opens that message', () async {
    final (c, a) = make();
    a.start();
    await Future<void>.delayed(Duration.zero);
    behind = true;
    inbox.insert(0, row('n2', link: {'type': 'screen', 'target': '/classes'}));
    await a.poll();
    await messenger.handlePlatformMessage(ch.name, ch.codec.encodeMethodCall(const MethodCall('open', 'n2')), (_) {});
    expect(opened.single, ['n2', 'screen', '/classes']);
    a.stop();
    c.dispose();
  });
}
