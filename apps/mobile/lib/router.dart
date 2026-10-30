import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/auth_screens.dart';
import 'features/cbt/cbt_screen.dart';
import 'features/home/home_screen.dart';
import 'features/news/news_screens.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/profile/profile_screens.dart';
import 'features/results/results_screens.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/shell.dart';
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
      if (!signedIn && !_public.contains(path)) return '/login';
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
        builder: (_, s) => VerifyCodeScreen(args: s.extra as VerifyArgs),
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset',
        builder: (_, s) => NewPasswordScreen(args: s.extra as ResetArgs?),
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
            routes: [
              GoRoute(
                path: '/study',
                builder: (_, _) => const ComingSoonScreen(kind: 'study'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/test', builder: (_, _) => const TestHubScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (_, _) => const ComingSoonScreen(kind: 'ai'),
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
