import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/classes/classes.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Online classes (C13, D-147).
Map<String, dynamic> _c(
  String id,
  Duration fromNow, {
  String access = 'free',
  bool registered = false,
  bool allowed = true,
  int? price,
  bool recording = false,
}) => {
  'id': id,
  'title': 'Class $id',
  'teacher': 'Mr Ade',
  'starts_at': DateTime.now().add(fromNow).toUtc().toIso8601String(),
  'minutes': 60,
  'access': access,
  'price_kobo': price,
  'status': 'published',
  'registered': registered,
  'allowed': allowed,
  'has_recording': recording,
  'taken': 3,
  'seats': null,
};

Widget _app(Widget home, List<Map<String, dynamic>> list) => ProviderScope(
  overrides: [classesProvider.overrideWith((_) async => list)],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  test('a class is live from 15 minutes before the start until the end', () {
    final now = DateTime.now();
    expect(classPhase(_c('a', const Duration(hours: 2)), now), ClassPhase.upcoming);
    expect(classPhase(_c('a', const Duration(minutes: 10)), now), ClassPhase.live);
    expect(classPhase(_c('a', const Duration(minutes: -30)), now), ClassPhase.live);
    expect(classPhase(_c('a', const Duration(minutes: -61)), now), ClassPhase.ended);
    expect(classPhase({..._c('a', const Duration(hours: 2)), 'status': 'cancelled'}, now), ClassPhase.cancelled);
  });

  test('the next class is the one I registered for, else the first coming up', () {
    final now = DateTime.now();
    final list = [_c('a', const Duration(hours: 1)), _c('b', const Duration(days: 2), registered: true), _c('c', const Duration(days: -2))];
    expect(nextClass(list, now)?['id'], 'b');
    expect(nextClass([list[0], list[2]], now)?['id'], 'a');
    expect(nextClass([list[2]], now), isNull);
  });

  testWidgets('classes list groups live, coming up and past', (t) async {
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(const ClassesScreen(), [
        _c('live', const Duration(minutes: 5)),
        _c('soon', const Duration(days: 1), access: 'paid', price: 200000),
        _c('old', const Duration(days: -3), recording: true),
      ]),
    );
    await _settle(t);
    expect(find.text('Live now'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Past classes'), findsOneWidget);
    expect(find.text('₦2,000'), findsOneWidget);
    expect(find.text('Recording'), findsOneWidget);
  });

  testWidgets('a class shows the right action', (t) async {
    t.view.physicalSize = const Size(1200, 2600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final list = [
      _c('free', const Duration(days: 1)),
      _c('live', const Duration(minutes: 5), registered: true),
      _c('prem', const Duration(days: 1), access: 'premium', allowed: false),
      _c('mine', const Duration(days: 1), registered: true),
      _c('old', const Duration(days: -3), recording: true),
    ];
    for (final (id, text) in [
      ('free', 'Register for free'),
      ('live', 'Join the class now'),
      ('prem', 'Go Premium to join'),
      ('mine', 'Registered · opens 15 min before'),
      ('old', 'Watch the recording'),
    ]) {
      await t.pumpWidget(_app(ClassScreen(key: ValueKey(id), id: id), list));
      await _settle(t);
      expect(find.text(text), findsOneWidget, reason: id);
    }
  });
}
