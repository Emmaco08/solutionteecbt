import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/ads.dart';
import 'core/house_ads.dart';

import 'features/ai/ai_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/cbt/cbt_screen.dart';
import 'features/test/custom_exam.dart';
import 'features/home/home_screen.dart';
import 'features/news/news_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/premium/checkout.dart';
import 'features/premium/paid_return.dart';
import 'features/profile/profile_screens.dart';
import 'features/results/results_screens.dart';
import 'features/setup/age_gate.dart';
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
import 'core/updater.dart';
import 'features/compete/mock_exam.dart';
import 'features/compete/challenges_screens.dart';
import 'features/compete/results_screens.dart';
import 'features/invite/invite_screens.dart';
import 'features/xp/streak_ui.dart';
import 'features/xp/xp_screens.dart';
import 'features/test/leaderboard_screen.dart';
import 'features/test/test_screens.dart';
import 'features/search/search_screen.dart';
import 'features/careers/careers.dart';
import 'features/profile/badges.dart';
import 'features/classes/classes.dart';
import 'features/tutor/tutor.dart';
import 'features/tutor/tutor_quiz.dart';
import 'features/games/games.dart';
import 'features/games/game_play.dart';
import 'features/games/arena.dart';
import 'features/community/community.dart';

/// Screens anyone can open without an account.
const _public = {
  '/splash',
  '/welcome',
  '/onboarding',
  '/login',
  '/signup',
  '/verify',
  '/forgot',
  '/reset',
  '/legal',
  '/phone-banned',
  '/clone-blocked',
  '/help',
  '/age-blocked',
};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _StreamListenable(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    navigatorKey: rootNavKey,
    observers: [AdsRouteObserver()],
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
      GoRoute(path: '/guardian', builder: (_, _) => const GuardianScreen()),
      GoRoute(path: '/age-blocked', builder: (_, _) => const AgeBlockedScreen()),
      GoRoute(path: '/account-paused', builder: (_, _) => const AccountPausedScreen()),
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
            routes: [
              GoRoute(
                path: '/test',
                builder: (_, _) => const TestHubScreen(),
                routes: [
                  GoRoute(
                    path: 'challenges',
                    builder: (_, _) => const ChallengesScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, s) => ChallengeScreen(id: s.pathParameters['id']!),
                        routes: [
                          GoRoute(
                            path: 'result',
                            builder: (_, s) => ChallengeResultScreen(id: s.pathParameters['id']!),
                          ),
                          GoRoute(
                            path: 'winners',
                            builder: (_, s) => ChallengeResultScreen(id: s.pathParameters['id']!),
                          ),
                          GoRoute(
                            path: 'claim',
                            builder: (_, s) => ClaimPrizeScreen(id: s.pathParameters['id']!),
                          ),
                          GoRoute(
                            path: 'appeal',
                            builder: (_, s) => AppealScreen(id: s.pathParameters['id']!),
                          ),
                          GoRoute(
                            path: 'review',
                            builder: (_, s) => ChallengeReviewScreen(id: s.pathParameters['id']!),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(path: 'winners-wall', builder: (_, _) => const WinnersWallScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (_, s) => AiScreen(
                  chatId: s.uri.queryParameters['chat'],
                  questionId: s.uri.queryParameters['q'],
                  questionLabel: s.uri.queryParameters['label'],
                  tool: s.uri.queryParameters['tool'],
                  toolArgs: AiScreen.parseArgs(s.uri.queryParameters['args']),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(path: 'winnings', builder: (_, _) => const WinningsScreen()),
                  GoRoute(path: 'invite', builder: (_, _) => const InviteScreen()),
                  GoRoute(path: 'xp', builder: (_, _) => const XpWalletScreen()),
                  GoRoute(path: 'streak', builder: (_, _) => const StreakScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/test/custom',
        builder: (_, s) => CustomExamScreen(examCode: s.uri.queryParameters['exam'] ?? 'JAMB'),
      ),
      GoRoute(
        path: '/test/setup',
        builder: (_, s) => TestSetupScreen(
          examCode: s.uri.queryParameters['exam'] ?? 'JAMB',
          mode: s.uri.queryParameters['mode'],
          subjectId: int.tryParse(s.uri.queryParameters['subject'] ?? ''),
          topic: s.uri.queryParameters['topic'],
        ),
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
      // Challenges live inside the Test tab so the bottom tabs stay visible (owner, D-073); playing is full screen.
      // Old links (/challenges/…, /winnings, /winners-wall) still work: they redirect into the tabs.
      GoRoute(
        path: '/challenges/:id/play',
        builder: (_, s) => ChallengePlayScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/mock',
        builder: (_, s) => MockExamScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/challenges', redirect: (_, _) => '/test/challenges'),
      GoRoute(path: '/challenges/:id', redirect: (_, s) => '/test/challenges/${s.pathParameters['id']}'),
      GoRoute(path: '/challenges/:id/:page', redirect: (_, s) => '/test/challenges/${s.pathParameters['id']}/${s.pathParameters['page']}'),
      GoRoute(path: '/winnings', redirect: (_, _) => '/me/winnings'),
      GoRoute(path: '/invite', redirect: (_, _) => '/me/invite'),
      GoRoute(path: '/xp', redirect: (_, _) => '/me/xp'),
      GoRoute(path: '/streak', redirect: (_, _) => '/me/streak'),
      // 4E3 (D-078): shown instead of the app; no tabs, no back.
      GoRoute(path: '/banned', builder: (_, _) => const BannedScreen()),
      GoRoute(path: '/phone-taken', builder: (_, _) => const PhoneTakenScreen()),
      GoRoute(path: '/phone-banned', builder: (_, _) => const PhoneBannedScreen()),
      GoRoute(path: '/clone-blocked', builder: (_, _) => const CloneBlockedScreen()),
      GoRoute(path: '/winners-wall', redirect: (_, _) => '/test/winners-wall'),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/update', builder: (_, _) => const AppUpdateScreen()),
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
      GoRoute(path: '/study/search', builder: (_, _) => const AppSearchScreen()),
      GoRoute(path: '/search', builder: (_, _) => const AppSearchScreen()),
      GoRoute(path: '/careers', builder: (_, _) => const CareersScreen()),
      GoRoute(path: '/badges', builder: (_, _) => const BadgesScreen()),
      GoRoute(path: '/classes', builder: (_, _) => const ClassesScreen()),
      GoRoute(path: '/tutor', builder: (_, _) => const TutorScreen()),
      GoRoute(path: '/tutor/paid', builder: (_, _) => const TutorPaidScreen()),
      GoRoute(path: '/tutor/quizzes', builder: (_, _) => const TutorQuizzesScreen()),
      GoRoute(
        path: '/tutor/quiz/:id',
        builder: (_, s) => TutorQuizScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/games', builder: (_, _) => const GamesScreen()),
      GoRoute(
        path: '/community',
        builder: (_, s) => CommunityShell(tab: const {'explore': 1, 'notifications': 2, 'me': 3}[s.uri.queryParameters['tab']] ?? 0),
      ),
      GoRoute(path: '/community/me', builder: (_, _) => const CommunityShell(tab: 3)),
      GoRoute(path: '/community/notifications', builder: (_, _) => const CommunityShell(tab: 2)),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, s) => ThreadScreen(id: s.pathParameters['id']!, reply: s.uri.queryParameters['reply'] == '1'),
      ),
      GoRoute(
        path: '/community/user/:id',
        builder: (_, s) => ProfileView(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/community/u/:handle',
        builder: (_, s) => ProfileView(handle: s.pathParameters['handle']!),
      ),
      GoRoute(
        path: '/community/compose',
        builder: (_, s) {
          final x = s.extra is Map ? Map<String, dynamic>.from(s.extra! as Map) : const <String, dynamic>{};
          return ComposeScreen(
            quote: x['quote'] is Map ? Map<String, dynamic>.from(x['quote'] as Map) : null,
            subject: (x['subject'] as num?)?.toInt(),
            text: x['text'] as String?,
            page: x['page'] is Map ? Map<String, dynamic>.from(x['page'] as Map) : null,
          );
        },
      ),
      GoRoute(path: '/community/edit', builder: (_, _) => const CommunityEditScreen()),
      GoRoute(path: '/community/subjects', builder: (_, _) => const AllSubjectsScreen()),
      GoRoute(
        path: '/community/tag/:tag',
        builder: (_, s) => TagFeedScreen(tag: s.pathParameters['tag']!),
      ),
      GoRoute(
        path: '/community/subject/:id',
        builder: (_, s) => TagFeedScreen(subject: int.tryParse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/community/follows/:id',
        builder: (_, s) =>
            FollowListScreen(id: s.pathParameters['id']!, kind: s.uri.queryParameters['kind'] ?? 'followers', name: s.uri.queryParameters['name']),
      ),
      GoRoute(
        path: '/games/play/:id',
        builder: (_, s) => GamePlayScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/games/arena/:id',
        builder: (_, s) => ArenaScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/classes/:id',
        builder: (_, s) => ClassScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/careers/:id',
        builder: (_, s) => CareerScreen(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
      ),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      GoRoute(path: '/ai/history', builder: (_, _) => const AiHistoryScreen()),
      // Payments (milestone 4C). The server sets the price and gives Premium only after checking the payment.
      GoRoute(
        path: '/checkout',
        builder: (_, s) => CheckoutScreen(planCode: s.uri.queryParameters['plan'] ?? 'three_months'),
      ),
      GoRoute(
        // Back from the payment website (D-116): solutiontee://app/paid?ref=…&plan=…
        path: '/paid',
        builder: (_, s) =>
            PaidReturnScreen(reference: s.uri.queryParameters['ref'] ?? '', plan: s.uri.queryParameters['plan'], kind: s.uri.queryParameters['kind']),
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
