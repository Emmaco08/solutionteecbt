/// Build-time configuration. Only PUBLIC values live in the app (SECURITY.md §1): the Supabase URL and the
/// publishable key are designed to be public; Row Level Security protects the data.
/// Override per build with --dart-define (see apps/mobile/README.md).
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://mxeemubacnmcmmmzteax.supabase.co');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_vdWEYzp3_AGA3cbhkwNAnA_oYzB-x43');

  /// Website API (sign-up codes, password reset, account deletion). In development, the laptop over USB:
  /// run `adb reverse tcp:3000 tcp:3000` so the phone's localhost:3000 reaches the laptop.
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3000');

  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const disclaimer =
      'SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.';
}
