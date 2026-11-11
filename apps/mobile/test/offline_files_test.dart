import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/offline_files.dart';
import 'package:solutiontee_cbt/features/study/downloads_screen.dart';
import 'package:solutiontee_cbt/features/study/offline_button.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Save videos and PDFs for offline (A4, D-139).
final _now = DateTime(2026, 11, 11, 12);

SavedFile _file({bool free = false, int daysSinceCheck = 0, String file = '360'}) => SavedFile(
  id: 'v1',
  file: file,
  kind: file == 'pdf' ? 'doc' : 'video_solution',
  title: 'Quadratic equations',
  bytes: 54 * 1024 * 1024,
  savedAt: _now,
  checkedAt: _now.subtract(Duration(days: daysSinceCheck)),
  free: free,
);

class _Fixed extends OfflineFiles {
  _Fixed(this.files);
  final Map<String, SavedFile> files;
  @override
  Map<String, SavedFile> build() {
    ready = Future.value();
    return files;
  }
}

class _Job extends OfflineJobs {
  @override
  Map<String, double> build() => const {'v1': .4};
}

void main() {
  test('a saved file keeps everything after a round trip', () {
    final f = SavedFile.fromJson(_file(file: '720').toJson());
    expect(f.file, '720');
    expect(f.isVideo, isTrue);
    expect(f.fileName, 'v1-720.mp4');
    expect(f.bytes, 54 * 1024 * 1024);
    expect(SavedFile.fromJson(_file(file: 'pdf').toJson()).fileName, 'v1-pdf.pdf');
  });

  test('Premium files open offline for 30 days after the last plan check; free files always', () {
    expect(openableOffline(_file(daysSinceCheck: 29), _now), isTrue);
    expect(openableOffline(_file(daysSinceCheck: 31), _now), isFalse);
    expect(openableOffline(_file(free: true, daysSinceCheck: 400), _now), isTrue);
  });

  test('file sizes read simply', () {
    expect(fileSize(820 * 1024), '820 KB');
    expect(fileSize(5.5 * 1024 * 1024), '5.5 MB');
    expect(fileSize(54 * 1024 * 1024), '54 MB');
  });

  // A fresh scope each time (a scope's overrides cannot change).
  Widget bar(Widget child, List overrides) => ProviderScope(
    key: UniqueKey(),
    overrides: [...overrides],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(appBar: AppBar(actions: [child])),
    ),
  );
  final item = {
    'id': 'v1',
    'kind': 'video_solution',
    'title': 'Quadratic equations',
    'files': {'360': true},
  };

  testWidgets('the button offers to save, shows progress, then shows it is saved', (t) async {
    await t.pumpWidget(bar(OfflineButton(item: item), [offlineFilesProvider.overrideWith(() => _Fixed(const {}))]));
    expect(find.bySemanticsLabel('Save for offline'), findsOneWidget);

    await t.pumpWidget(bar(OfflineButton(item: item), [offlineFilesProvider.overrideWith(() => _Fixed(const {})), offlineJobsProvider.overrideWith(_Job.new)]));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await t.pumpWidget(
      bar(OfflineButton(item: item), [
        offlineFilesProvider.overrideWith(() => _Fixed({'v1': _file()})),
      ]),
    );
    await t.pump();
    expect(find.bySemanticsLabel('Saved on this phone'), findsOneWidget);
  });

  testWidgets('items without a file show no button', (t) async {
    await t.pumpWidget(bar(OfflineButton(item: const {'id': 'x', 'files': {}}), [offlineFilesProvider.overrideWith(() => _Fixed(const {}))]));
    expect(find.byType(IconButton), findsNothing);
    expect(find.bySemanticsLabel('Save for offline'), findsNothing);
  });

  testWidgets('Downloads lists saved videos and PDFs with their size', (t) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          examsProvider.overrideWith((_) async => const <Map<String, dynamic>>[]),
          offlineFilesProvider.overrideWith(
            () => _Fixed({
              'v1': _file(),
              'd1': SavedFile.fromJson({..._file(file: 'pdf').toJson(), 'id': 'd1', 'title': 'JAMB Brochure', 'bytes': 820 * 1024}),
            }),
          ),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const DownloadsScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Quadratic equations'), findsOneWidget);
    expect(find.text('Video · 54 MB'), findsOneWidget);
    expect(find.text('JAMB Brochure'), findsOneWidget);
    expect(find.text('PDF · 820 KB'), findsOneWidget);
  });
}
