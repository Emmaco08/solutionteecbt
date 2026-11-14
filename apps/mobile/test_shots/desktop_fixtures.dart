// Routes and sample data for the desktop screenshots (D-166). Real screens only; data is made up.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/ai/ai_screen.dart';
import 'package:solutiontee_cbt/features/auth/auth_screens.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';
import 'package:solutiontee_cbt/features/classes/classes.dart';
import 'package:solutiontee_cbt/features/community/community.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_hub.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart';
import 'package:solutiontee_cbt/features/news/news_screens.dart';
import 'package:solutiontee_cbt/features/notifications/notifications_screen.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_screens.dart';
import 'package:solutiontee_cbt/features/profile/profile_screens.dart';
import 'package:solutiontee_cbt/features/results/results_screens.dart';
import 'package:solutiontee_cbt/features/study/study_hub.dart';
import 'package:solutiontee_cbt/features/test/leaderboard_screen.dart';
import 'package:solutiontee_cbt/features/test/test_screens.dart';
import 'package:solutiontee_cbt/features/tutor/tutor.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';

const desktopScreens = [
  ('/welcome', 'welcome'),
  ('/login', 'login'),
  ('/home', 'home'),
  ('/test', 'test'),
  ('/study', 'study'),
  ('/ai', 'ai'),
  ('/me', 'me'),
  ('/cbt/att1', 'cbt'),
  ('/community', 'community'),
  ('/games', 'games'),
  ('/leaderboard', 'leaderboard'),
  ('/classes', 'classes'),
  ('/tutor', 'tutor'),
  ('/news', 'news'),
  ('/notifications', 'notifications'),
  ('/settings', 'settings'),
];

List<RouteBase> desktopRoutes() => [
  GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(path: '/signup', builder: (_, _) => const SignUpScreen()),
  GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
  GoRoute(path: '/test', builder: (_, _) => const TestHubScreen()),
  GoRoute(path: '/study', builder: (_, _) => const StudyScreen()),
  GoRoute(path: '/ai', builder: (_, _) => const AiScreen()),
  GoRoute(path: '/me', builder: (_, _) => const ProfileScreen()),
  GoRoute(
    path: '/cbt/:id',
    builder: (_, s) => CbtScreen(attemptId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/results/:id',
    builder: (_, s) => ResultsScreen(attemptId: s.pathParameters['id']!),
  ),
  GoRoute(path: '/community', builder: (_, _) => const CommunityShell(tab: 0)),
  GoRoute(path: '/games', builder: (_, _) => const GzHubScreen()),
  GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardScreen()),
  GoRoute(path: '/classes', builder: (_, _) => const ClassesScreen()),
  GoRoute(path: '/tutor', builder: (_, _) => const TutorScreen()),
  GoRoute(path: '/news', builder: (_, _) => const NewsListScreen()),
  GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
  GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  GoRoute(
    path: '/search',
    builder: (_, _) => const Scaffold(body: Center(child: Text('Search'))),
  ),
];

List fixtureOverrides() => [
  profileProvider.overrideWith((_) async => {'full_name': 'Tolu Adeyemi', 'exam_target': 'JAMB'}),
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
      'current': 12,
      'best': 21,
      'xp': {'enabled': true, 'balance': 2480, 'claimed_today': true},
    },
  ),
];

/// Real marking on this computer, no network sync.
class OfflineRepo extends TestsRepo {
  OfflineRepo(super.ref);
  @override
  Future<int> syncPending() async => 0;
}
