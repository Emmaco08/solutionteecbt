// WhatsApp channel card and pop-up (D-174). Not part of `flutter test`.
// Run: flutter test test_shots/wa_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/home/whatsapp_channel.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

const ch = WaChannel(
  url: 'https://whatsapp.com/channel/0029VaTEST',
  title: 'Join our WhatsApp channel',
  text: 'Exam news, free study tips and class alerts, first. Free to join.',
  popup: true,
);

Future<void> _shot(WidgetTester t, Widget w, String name, {Brightness mode = Brightness.light, Size size = const Size(390, 844), bool joined = false}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith((ref) async => {'whatsapp_channel': {'enabled': true, 'url': ch.url}}),
        waJoinedProvider.overrideWith((ref) async => joined),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(mode), home: w),
    ),
  );
  for (var i = 0; i < 16; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/wa/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 6));
}

Widget _page(BuildContext? _, {double pad = 20}) => Scaffold(
  body: ListView(padding: EdgeInsets.all(pad), children: const [SizedBox(height: 300), WhatsAppChannelCard()]),
);

void main() {
  setUpAll(() async {
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });
  testWidgets('card phone light', (t) => _shot(t, _page(null), 'card_phone_light'));
  testWidgets('card phone dark', (t) => _shot(t, _page(null), 'card_phone_dark', mode: Brightness.dark));
  testWidgets('card joined', (t) => _shot(t, _page(null), 'card_phone_joined', joined: true));
  testWidgets('card laptop', (t) => _shot(t, _page(null, pad: 60), 'card_laptop', size: const Size(1100, 700)));
  for (final m in Brightness.values) {
    testWidgets('popup ${m.name}', (t) => _shot(t, const Scaffold(backgroundColor: Colors.black54, body: WhatsAppPopup(ch: ch)), 'popup_${m.name}', mode: m));
  }
  testWidgets('popup laptop', (t) => _shot(t, const Scaffold(backgroundColor: Colors.black54, body: WhatsAppPopup(ch: ch)), 'popup_laptop', size: const Size(1366, 768)));
}
