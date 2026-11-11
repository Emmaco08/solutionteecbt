import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/fair_play.dart';
import 'package:solutiontee_cbt/data/db.dart';

// Fair-play tracking (B10, D-144).
void main() {
  late AppDb db;
  setUp(() => db = AppDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a test with nothing recorded reports zeros', () async {
    expect(await FairPlay.report(db, 't1'), {'away': 0, 'away_ms': 0, 'shots': 0});
  });

  test('leaving the app and screenshot tries add up, a quick glance does not count', () async {
    final f = FairPlay(db, 't1');
    f.left();
    await f.back(); // under 1.5 s: a glance, not leaving
    expect((await FairPlay.report(db, 't1'))!['away'], 0);

    f.left();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    await f.back();
    await f.screenshot();
    await f.screenshot();
    final r = (await FairPlay.report(db, 't1'))!;
    expect(r['away'], 1);
    expect(r['away_ms'] as int, greaterThanOrEqualTo(1500));
    expect(r['shots'], 2);

    // Kept per test, and cleared once the server has it.
    expect((await FairPlay.report(db, 't2'))!['shots'], 0);
    await FairPlay.clear(db, 't1');
    expect((await FairPlay.report(db, 't1'))!['shots'], 0);
  });
}
