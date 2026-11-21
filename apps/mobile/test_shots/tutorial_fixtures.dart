// Sample data for the app tutorial videos (test_shots/tutorial_test.dart, D-187). Made up, shaped like the server's
// rows. tutTables answers table reads, tutRpc answers RPCs, tutFunctions answers Edge Functions.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_data.dart';
import 'package:solutiontee_cbt/features/profile/badges.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';

import 'laptop_fixtures.dart';

const tutUid = '00000000-0000-4000-8000-000000000001';

final tutSubjects = [
  {'id': 11, 'code': 'eng', 'name': 'Use of English'},
  {'id': 10, 'code': 'mth', 'name': 'Mathematics'},
  {'id': 12, 'code': 'phy', 'name': 'Physics'},
  {'id': 13, 'code': 'chm', 'name': 'Chemistry'},
  {'id': 14, 'code': 'bio', 'name': 'Biology'},
  {'id': 15, 'code': 'eco', 'name': 'Economics'},
  {'id': 16, 'code': 'gov', 'name': 'Government'},
  {'id': 17, 'code': 'lit', 'name': 'Literature in English'},
];

final tutTables = <String, Object>{
  'subjects': tutSubjects,
  'exam_subjects': [
    for (final s in tutSubjects) {'exam_id': 1, 'subject_id': s['id'], 'compulsory': s['code'] == 'eng', 'question_count': s['code'] == 'eng' ? 60 : 40, 'minutes': null},
    for (final s in tutSubjects) {'exam_id': 2, 'subject_id': s['id'], 'compulsory': false, 'question_count': 50, 'minutes': 60},
  ],
  'topics': [
    for (final (i, n) in ['Logarithms', 'Quadratic equations', 'Indices', 'Probability', 'Statistics', 'Sets'].indexed) {'id': 100 + i, 'subject_id': 10, 'name': n, 'sort': i},
    for (final (i, n) in ['Motion', 'Waves', 'Electricity', 'Heat'].indexed) {'id': 200 + i, 'subject_id': 12, 'name': n, 'sort': i},
    for (final (i, n) in ['Mole concept', 'Organic chemistry', 'Electrolysis'].indexed) {'id': 300 + i, 'subject_id': 13, 'name': n, 'sort': i},
    for (final (i, n) in ['Comprehension', 'Lexis and structure', 'Oral English'].indexed) {'id': 400 + i, 'subject_id': 11, 'name': n, 'sort': i},
  ],
  'app_settings': [
    {
      'key': 'custom_exam',
      'value': {'on': true, 'who': 'everyone', 'max_questions': 40, 'max_english': 60, 'max_minutes': 180},
    },
  ],
};

final tutRpc = <String, Object?>{
  'my_open_years': [
    for (final s in [10, 11, 12, 13, 14])
      for (final y in [2023, 2022, 2021, 2020, 2019]) {'exam_id': 1, 'subject_id': s, 'year': y, 'cbt_open': true},
  ],
  'my_plan': {'tier': 'free'},
  'set_birth_year': {'ok': true},
  'community_home': tutPosts,
  'community_thread': {
    ...tutPosts[0],
    'replies': [
      {'id': 'r1', 'user_id': 'u-davidokon', 'name': 'David Okon', 'handle': 'davidokon', 'avatar_path': null, 'body': 'Factorise it: (x − 2)(x − 3) = 0, so x = 2 or x = 3.', 'likes': 5, 'liked': false, 'created_at': _ago(12), 'reply_list': const [], 'mine': false},
      {'id': 'r2', 'user_id': 'u-amaka.eze', 'name': 'Amaka Eze', 'handle': 'amaka.eze', 'avatar_path': null, 'body': 'Find two numbers that multiply to 6 and add up to −5. That is −2 and −3.', 'likes': 3, 'liked': false, 'created_at': _ago(9), 'reply_list': const [], 'mine': false},
    ],
  },
  'community_mention_suggest': [
    {'id': 'u-davidokon', 'name': 'David Okon', 'handle': 'davidokon', 'avatar_path': null},
    {'id': 'u-david.a', 'name': 'David Adeleke', 'handle': 'david.a', 'avatar_path': null},
  ],
  'community_reply': {'ok': true, 'id': 'r9', 'status': 'shown'},
  'community_post_send': {'ok': true, 'id': 'p9', 'status': 'shown'},
  'community_follow': {'ok': true, 'following': true},
  'community_unread': 0,
  'community_new_count': 0,
};

final tutFunctions = <String, Object?>{};

String _ago(int minutes) => DateTime.now().subtract(Duration(minutes: minutes)).toUtc().toIso8601String();

Map<String, Object?> _post(String id, String name, String handle, String body, {int subject = 10, int likes = 0, int replies = 0, bool following = false, String? ai, int ago = 30}) => {
  'id': id,
  'user_id': 'u-$handle',
  'name': name,
  'handle': handle,
  'avatar_path': null,
  'badge': null,
  'body': body,
  'images': const [],
  'subject_id': subject,
  'likes': likes,
  'liked': false,
  'replies': replies,
  'comments': replies,
  'reposts': 0,
  'reposted': false,
  'bookmarked': false,
  'created_at': _ago(ago),
  'status': 'shown',
  'mine': false,
  'following': following,
  'ai_answer': ai,
  'quote': null,
  'page_id': null,
  'official': false,
};

final tutPosts = [
  _post('p1', 'Kemi Bello', 'kemi_b', 'Please how do I solve this? Find the roots of x² − 5x + 6 = 0. I keep getting it wrong.', likes: 12, replies: 3, ago: 18),
  _post('p2', 'David Okon', 'davidokon', 'Tip: for Use of English, read the passage questions FIRST, then the passage. It saves so much time in the CBT. #JAMB2027', subject: 11, likes: 48, replies: 9, ago: 55),
  _post('p3', 'Amaka Eze', 'amaka.eze', 'Just scored 78% in my Physics mock! Waves and Electricity are finally making sense. Who else is practising today?', subject: 12, likes: 31, replies: 6, ago: 120),
  _post('p4', 'Musa Ibrahim', 'musa_i', 'Can someone explain the mole concept in simple terms? Chemistry is giving me headache.', subject: 13, likes: 7, replies: 2, ago: 200),
];

/// Provider overrides (the laptop check's sample data, with this student's profile and subjects).
List tutorialOverrides() => [
  badgesProvider.overrideWith((_) async => badgesFixture),
  gzHomeProvider.overrideWith((_) async => gzHomeFixture),
  gzLeadersProvider.overrideWith((_, _) async => gzLeadersFixture),
  newsProvider.overrideWith((_) async => newsFixture),
  profileProvider.overrideWith(
    (_) async => {
      'full_name': 'Tolu Adeyemi',
      'exam_target': 'JAMB',
      'target_exams': ['JAMB'],
      'jamb_subjects': ['eng', 'mth', 'phy', 'chm'],
      'state': 'Oyo',
    },
  ),
  myPlanProvider.overrideWith((_) async => {'tier': 'free'}),
  subjectsProvider.overrideWith((_) async => tutSubjects),
  examsProvider.overrideWith(
    (_) async => [
      {
        'id': 1,
        'code': 'JAMB',
        'name': 'JAMB UTME',
        'subtitle': '4 subjects · 180 questions · 2 hours',
        'exam_configs': {'total_minutes': 120, 'total_questions': 180, 'subjects_per_candidate': 4},
      },
      {'id': 2, 'code': 'WAEC', 'name': 'WAEC WASSCE', 'subtitle': 'Objective papers per subject'},
      {'id': 3, 'code': 'NECO', 'name': 'NECO SSCE', 'subtitle': 'Objective papers per subject'},
    ],
  ),
  myStreakProvider.overrideWith(
    (_) async => {
      'current': 6,
      'best': 14,
      'xp': {'enabled': true, 'balance': 860, 'claimed_today': true},
    },
  ),
];

/// Questions on this phone, so tests can start offline.
/// Sample questions per subject (shown in the tutorials), cycled to fill each paper: [body, A, B, C, D, answer].
const _bank = <int, List<List<String>>>{
  11: [
    ['Choose the option that best completes the sentence: Neither the teacher nor the students ___ in the hall.', 'was', 'were', 'is', 'be', 'B'],
    ['Choose the option nearest in meaning to the word in capitals: The manager was ADAMANT about the new rules.', 'firm', 'unsure', 'happy', 'angry', 'A'],
    ['Choose the option opposite in meaning to the word in capitals: Water is SCARCE during the dry season.', 'rare', 'plentiful', 'costly', 'clean', 'B'],
    ['Choose the correctly spelt word.', 'Accomodation', 'Acommodation', 'Accommodation', 'Acomodation', 'C'],
    ['Choose the option that best completes the sentence: She has been living in Lagos ___ 2019.', 'for', 'since', 'from', 'by', 'B'],
  ],
  10: [
    ['Find the roots of the equation x² − 5x + 6 = 0.', 'x = 2 or 3', 'x = −2 or −3', 'x = 1 or 6', 'x = −1 or 6', 'A'],
    ['Find the value of x if 3x − 7 = 11.', '4', '6', '5', '18/7', 'B'],
    ['What is the mean of 4, 6, 8 and 10?', '6', '7', '8', '28', 'B'],
    ['Simplify 2³ × 2⁴.', '2⁷', '2¹²', '4⁷', '2', 'A'],
    ['Express 0.375 as a fraction in its lowest terms.', '3/8', '3/5', '375/100', '5/8', 'A'],
  ],
  12: [
    ['Which of these is a vector quantity?', 'Mass', 'Speed', 'Velocity', 'Time', 'C'],
    ['The SI unit of force is the', 'joule', 'newton', 'watt', 'pascal', 'B'],
    ['A car travels 120 m in 6 s. What is its average speed?', '20 m/s', '720 m/s', '12 m/s', '2 m/s', 'A'],
    ['Sound cannot travel through', 'water', 'air', 'steel', 'a vacuum', 'D'],
    ['Which colour of light has the longest wavelength?', 'Blue', 'Green', 'Red', 'Violet', 'C'],
  ],
  13: [
    ['What is the chemical symbol for sodium?', 'So', 'Na', 'S', 'Sd', 'B'],
    ['Which gas is given off when zinc reacts with dilute hydrochloric acid?', 'Oxygen', 'Chlorine', 'Hydrogen', 'Carbon dioxide', 'C'],
    ['The pH of a neutral solution at 25 °C is', '0', '7', '14', '1', 'B'],
    ['Which of these is an alkali metal?', 'Calcium', 'Potassium', 'Iron', 'Aluminium', 'B'],
    ['Rusting of iron needs', 'oxygen only', 'water only', 'oxygen and water', 'carbon dioxide', 'C'],
  ],
  14: [
    ['The powerhouse of the cell is the', 'nucleus', 'ribosome', 'mitochondrion', 'vacuole', 'C'],
    ['Which blood cells fight infection?', 'Red blood cells', 'White blood cells', 'Platelets', 'Plasma', 'B'],
    ['Photosynthesis takes place mainly in the', 'root', 'stem', 'leaf', 'flower', 'C'],
    ['The basic unit of heredity is the', 'gene', 'cell', 'tissue', 'organ', 'A'],
    ['Which of these is a mammal?', 'Shark', 'Whale', 'Frog', 'Crocodile', 'B'],
  ],
};

Future<void> seedTutorialDb(AppDb db) async {
  var n = 0;
  for (final sid in [10, 11, 12, 13, 14]) {
    final bank = _bank[sid]!;
    for (var i = 0; i < 60; i++) {
      final q = bank[i % bank.length];
      await db
          .into(db.cachedQuestions)
          .insert(
            CachedQuestionsCompanion.insert(
              id: 'q$sid-$i',
              examId: 1,
              subjectId: sid,
              year: 2023 - (i % 5),
              body: q[0],
              optionsJson: jsonEncode({'A': q[1], 'B': q[2], 'C': q[3], 'D': q[4]}),
              answer: q[5],
              topic: Value(sid == 10 && i % bank.length == 0 ? 'Quadratic equations' : null),
            ),
          );
      n++;
    }
  }
  assert(n > 0);
}

/// The student has worked through most of the paper: about three in four right, a few left blank, 1 h 32 min used.
Future<void> finishMostOfPaper(AppDb db, String attemptId) async {
  final a = await (db.select(db.localAttempts)..where((r) => r.id.equals(attemptId))).getSingle();
  final ids = (jsonDecode(a.questionIdsJson) as List).cast<String>();
  final qs = {for (final q in await db.select(db.cachedQuestions).get()) q.id: q};
  final done = {for (final x in await db.answersFor(attemptId)) if (x.choice != null) x.questionId};
  for (var i = 0; i < ids.length; i++) {
    if (i % 23 == 22 || done.contains(ids[i])) continue; // left blank, or answered on screen
    final right = qs[ids[i]]!.answer;
    final wrong = right == 'A' ? 'B' : 'A';
    await db.saveAnswer(attemptId, ids[i], choice: (i * 7) % 4 == 3 ? wrong : right, addMs: 30000);
  }
  await (db.update(db.localAttempts)..where((r) => r.id.equals(attemptId))).write(const LocalAttemptsCompanion(usedMs: Value(92 * 60 * 1000)));
}

/// Remembers what the student did, so the next screen shows it (a reply in the thread, a new post in the feed).
void tutRemember(String fn, Map<String, dynamic> p) {
  if (fn == 'community_reply') {
    final thread = tutRpc['community_thread']! as Map<String, Object?>;
    (thread['replies']! as List).add({
      'id': 'r9', 'user_id': tutUid, 'name': 'Tolu Adeyemi', 'handle': 'tolu_a', 'avatar_path': null, 'body': p['p_body'],
      'likes': 0, 'liked': false, 'created_at': DateTime.now().toUtc().toIso8601String(), 'reply_list': const [], 'mine': true,
    });
  }
  if (fn == 'community_post_send') {
    tutPosts.insert(0, {
      ...tutPosts[0], 'id': 'p9', 'user_id': tutUid, 'name': 'Tolu Adeyemi', 'handle': 'tolu_a', 'body': p['p_body'], 'subject_id': p['p_subject'],
      'likes': 0, 'replies': 0, 'comments': 0, 'created_at': DateTime.now().toUtc().toIso8601String(), 'mine': true,
    });
  }
  if (fn == 'community_follow') {
    (tutRpc['community_thread']! as Map<String, Object?>)['following'] = true;
  }
}
