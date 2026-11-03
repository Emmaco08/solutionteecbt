import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/ai/ai_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/cbt/cbt_screen.dart';
import 'features/home/home_screen.dart';
import 'features/news/news_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/premium/checkout.dart';
import 'features/profile/profile_screens.dart';
import 'features/results/results_screens.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/shell.dart';
import 'features/study/doc_screens.dart';
import 'features/study/downloads_screen.dart';
import 'features/study/note_screens.dart';
import 'features/study/novel_screens.dart';
import 'features/study/pq_screens.dart';
import 'features/study/study_hub.dart';
import 'features/study/video_screens.dart';
import 'features/compete/challenge_play.dart';
import 'features/compete/challenges_screens.dart';
import 'features/compete/results_screens.dart';
import 'features/test/leaderboard_screen.dart';
import 'features/test/test_screens.dart';

/// Screens anyone can open without an account.
const _public = {'/splash', '/welcome', '/onboarding', '/login', '/signup', '/verify', '/forgot', '/reset', '/legal'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _StreamListenable(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentSession != null;
      final path = state.uri.path;
      if (!signedIn && !_public.contains(path)) return '/welcome'; // logged out (or log out): Welcome, as in the prototype
      // The email code was accepted (now logged in): carry on to profile setup, never back to sign-up.
      if (signedIn && (path == '/verify' || path == '/signup')) return '/setup';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, s) {
          final a = s.extra as VerifyArgs? ?? VerifyArgs.last;
          return a == null ? const SignUpScreen() : VerifyCodeScreen(args: a);
        },
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset',
        builder: (_, s) => NewPasswordScreen(args: s.extra as ResetArgs? ?? ResetArgs.last),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/welcome-new', builder: (_, _) => const WelcomeNewScreen()),
      GoRoute(path: '/welcome-back', builder: (_, _) => const WelcomeBackScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, s) => HomeScreen(tour: s.uri.queryParameters['tour'] == '1'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/study', builder: (_, _) => const StudyScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/test', builder: (_, _) => const TestHubScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (_, s) =>
                    AiScreen(chatId: s.uri.queryParameters['chat'], questionId: s.uri.queryParameters['q'], questionLabel: s.uri.queryParameters['label']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/me', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/test/setup',
        builder: (_, s) => TestSetupScreen(examCode: s.uri.queryParameters['exam'] ?? 'JAMB', mode: s.uri.queryParameters['mode']),
      ),
      GoRoute(
        path: '/cbt/:id',
        builder: (_, s) => CbtScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/results/:id',
        builder: (_, s) => ResultsScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/review/:id',
        builder: (_, s) => ReviewScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardScreen()),
      GoRoute(path: '/challenges', builder: (_, _) => const ChallengesScreen()),
      GoRoute(
        path: '/challenges/:id',
        builder: (_, s) => ChallengeScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/play',
        builder: (_, s) => ChallengePlayScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/result',
        builder: (_, s) => ChallengeResultScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/winners',
        builder: (_, s) => ChallengeResultScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/claim',
        builder: (_, s) => ClaimPrizeScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/winnings', builder: (_, _) => const WinningsScreen()),
      GoRoute(path: '/winners-wall', builder: (_, _) => const WinnersWallScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: '/legal',
        builder: (_, s) => LegalScreen(page: s.uri.queryParameters['p'] ?? 'about'),
      ),
      GoRoute(path: '/delete-account', builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: '/subjects', builder: (_, _) => const SetupScreen(subjectsOnly: true)),
      GoRoute(path: '/edit-profile', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/news', builder: (_, _) => const NewsListScreen()),
      // Study (Phase 4A). The server decides what is open; these screens only show it.
      GoRoute(
        path: '/study/pq',
        builder: (_, s) => PqBrowseScreen(subjectId: int.tryParse(s.uri.queryParameters['subject'] ?? '')),
      ),
      GoRoute(
        path: '/study/pq/:exam/:subject/:year',
        builder: (_, s) => PqStudyScreen(
          examId: int.parse(s.pathParameters['exam']!),
          subjectId: int.parse(s.pathParameters['subject']!),
          year: int.parse(s.pathParameters['year']!),
          questionId: s.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/study/videos',
        builder: (_, s) => VideoListScreen(kind: s.uri.queryParameters['kind'] == 'lesson' ? 'lesson' : 'video_solution'),
      ),
      GoRoute(
        path: '/study/video/:id',
        builder: (_, s) => VideoPlayerScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/study/notes', builder: (_, _) => const NotesListScreen()),
      GoRoute(
        path: '/study/note/:id',
        builder: (_, s) => NoteScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/study/novels', builder: (_, _) => const NovelsScreen()),
      GoRoute(
        path: '/study/novel/:id',
        builder: (_, s) => NovelScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/study/docs', builder: (_, _) => const DocsScreen()),
      GoRoute(
        path: '/study/doc/:id',
        builder: (_, s) => DocScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/study/bookmarks', builder: (_, _) => const BookmarksScreen()),
      GoRoute(path: '/study/search', builder: (_, _) => const StudySearchScreen()),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      GoRoute(path: '/ai/history', builder: (_, _) => const AiHistoryScreen()),
      // Payments (milestone 4C). The server sets the price and gives Premium only after checking the payment.
      GoRoute(
        path: '/checkout',
        builder: (_, s) => CheckoutScreen(planCode: s.uri.queryParameters['plan'] ?? 'three_months'),
      ),
      GoRoute(
        path: '/pay-success',
        builder: (_, s) => PaySuccessScreen(info: (s.extra as Map<String, Object?>?) ?? const {}),
      ),
      GoRoute(
        path: '/news/:id',
        builder: (_, s) => NewsDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
});

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> s) : _sub = s.listen((_) {}) {
    _sub.onData((_) => notifyListeners());
  }
  final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
