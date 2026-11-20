// Sample data for the laptop check (test_shots/laptop_test.dart). Made up; pictures are test_shots/fixtures/*.jpg.
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_data.dart';
import 'package:solutiontee_cbt/features/profile/badges.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';

String _ago(int days) => DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

final newsFixture = <Map<String, dynamic>>[
  {
    'id': 'n1',
    'title': 'JAMB Extends CAPS Admission Acceptance Deadline to November 30',
    'summary': 'Candidates who have not accepted their admission offers now have more time.',
    'body':
        'The Joint Admissions and Matriculation Board has extended the deadline for accepting admission offers on CAPS.\n\n'
        'Candidates are advised to log in to the JAMB portal, check their admission status and accept or reject the offer before the new date.\n\n'
        'Students who miss the new deadline may lose their admission slot.',
    'category': 'exam',
    'image_path': 'news/wide.jpg',
    'publish_at': _ago(1),
    'is_pinned': true,
    'comments_on': true,
  },
  {
    'id': 'n2',
    'title': 'JAMB 2027: Why Every UTME Candidate Should Start Preparing Now',
    'summary': 'Early, steady practice beats cramming. Here is a simple plan.',
    'body': 'Start with your weakest subject.\n\nPractise one full mock every week.',
    'category': 'exam',
    'image_path': 'news/wide2.jpg',
    'publish_at': _ago(2),
    'comments_on': true,
  },
  {
    'id': 'n3',
    'title': 'Five study tips for the last month before WAEC',
    'summary': 'Small steps every day.',
    'body': 'Sleep well.\n\nRevise past questions.',
    'category': 'tips',
    'publish_at': _ago(3),
  },
  {
    'id': 'n4',
    'title': 'New in the app: Game Zone duels and Reading Race',
    'summary': 'Play live against students across Nigeria.',
    'body': 'Open Game Zone from Home.',
    'category': 'app',
    'image_path': 'news/wide3.jpg',
    'publish_at': _ago(4),
  },
];

Map<String, dynamic> _avatar(String skin, String hair, String shirt, {String face = 'grin'}) => {
  'photo': null,
  'has_photo': false,
  'preset': {'skin': skin, 'hair': hair, 'shirt': shirt, 'hairColor': '#1A1206', 'face': face, 'glasses': false, 'bg': '#5887C5'},
};

final gzHomeFixture = {
  'me': {'name': 'Emma', 'avatar': _avatar('#8D5524', 'afro', '#2563B3'), 'rating': 1240},
  'games': [
    for (final g in ['duel', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay', 'reading'])
      {'id': g, 'on': true, 'ready': true, 'online': g == 'duel' ? 128 : (g == 'rush' ? 34 : 0), 'rating': 1240, 'played': 4, 'won': 3, 'streak': 2},
  ],
  'subjects': [
    {'id': 1, 'code': 'eng', 'name': 'English'},
    {'id': 5, 'code': 'bio', 'name': 'Biology'},
  ],
  'active': null,
  'week': {'played': 14, 'won': 9, 'xp': 2480},
  'recent': [
    {'id': 'a', 'game': 'duel', 'mode': 'ranked', 'place': 1, 'score': 1180, 'xp': 35, 'rating_delta': 18, 'players': 2, 'vs': 'Kemi'},
  ],
};

final gzLeadersFixture = {
  'rows': [
    for (var i = 0; i < 9; i++)
      {
        'rank': i + 1,
        'name': ['Amaka', 'Chidi', 'Emma', 'Zainab', 'Emeka', 'Fola', 'Ibrahim', 'Ngozi', 'Seyi'][i],
        'me': i == 2,
        'avatar': _avatar(
          ['#5C3A1E', '#C68642', '#F1C27D'][i % 3],
          ['bun', 'fade', 'afro', 'hijab', 'cap', 'braids'][i % 6],
          ['#E0335A', '#1FA463', '#7A4FD6'][i % 3],
        ),
        'rating': 1720 - i * 60,
        'played': 20,
        'won': 14 - i,
      },
  ],
  'me': {'rating': 1600, 'played': 20},
};

/// 16 badges at different levels (the badges screen and the Me section, D-185).
final badgesFixture = <String, dynamic>{
  'on': true,
  'badges': [
    for (final (i, (name, icon)) in [
      ('Streak starter', 'fire'),
      ('Mock master', 'exam'),
      ('Sharp shooter', 'target'),
      ('Perfect score', 'checkFat'),
      ('Champion', 'trophy'),
      ('Speed demon', 'timer'),
      ('Verified genius', 'sealCheck'),
      ('On the rise', 'chartLineUp'),
      ('Lightning round', 'lightning'),
      ('Every day', 'calendarCheck'),
      ('Night owl', 'moonStars'),
      ('Early bird', 'sunHorizon'),
      ('Bookworm', 'books'),
      ('Video learner', 'playCircle'),
      ('Note taker', 'notePencil'),
      ('Helping hand', 'users'),
    ].indexed)
      {
        'id': 'b$i',
        'name': name,
        'icon': icon,
        'description': 'A sample badge.',
        'tier': i < 7 ? (4 - i % 4) : 0,
        'value': 30 + i * 7,
        'targets': {'bronze': 10, 'silver': 50, 'gold': 150, 'diamond': 400},
        'rewards': const {},
      },
  ],
};

List laptopOverrides() => [
  badgesProvider.overrideWith((_) async => badgesFixture),
  gzHomeProvider.overrideWith((_) async => gzHomeFixture),
  gzLeadersProvider.overrideWith((_, _) async => gzLeadersFixture),
  profileProvider.overrideWith(
    (_) async => {
      'full_name': 'Emma Akinbola',
      'exam_target': 'JAMB',
      'target_exams': ['JAMB'],
      'avatar_path': 'avatars/tall.jpg',
      'state': 'Oyo',
    },
  ),
  myPlanProvider.overrideWith((_) async => {'tier': 'free'}),
  subjectsProvider.overrideWith(
    (_) async => [
      {'id': 10, 'code': 'mth', 'name': 'Mathematics'},
      {'id': 11, 'code': 'eng', 'name': 'Use of English'},
      {'id': 12, 'code': 'phy', 'name': 'Physics'},
      {'id': 13, 'code': 'chm', 'name': 'Chemistry'},
    ],
  ),
  examsProvider.overrideWith(
    (_) async => [
      {
        'id': 1,
        'code': 'JAMB',
        'name': 'JAMB UTME',
        'exam_configs': {'total_minutes': 120, 'total_questions': 180, 'subjects_per_candidate': 4},
      },
      {'id': 2, 'code': 'WAEC', 'name': 'WAEC SSCE'},
      {'id': 3, 'code': 'NECO', 'name': 'NECO SSCE'},
    ],
  ),
  myStreakProvider.overrideWith(
    (_) async => {
      'current': 13,
      'best': 21,
      'xp': {'enabled': true, 'balance': 1410, 'claimed_today': true},
    },
  ),
  newsProvider.overrideWith((_) async => newsFixture),
  appSettingsProvider.overrideWith(
    (_) async => {
      'whatsapp_channel': {'enabled': true, 'popup': false, 'url': 'https://whatsapp.com/channel/0029VaTEST'},
      'leaderboard': {'on': true},
    },
  ),
];
