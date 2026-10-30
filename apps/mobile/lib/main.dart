import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/providers.dart';
import 'core/secure_storage.dart';
import 'data/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabasePublishableKey,
    // Session tokens live in the Android Keystore-backed secure storage, not plain preferences.
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );

  final db = AppDb();
  final settings = await loadSettings(db);

  runApp(ProviderScope(overrides: [dbProvider.overrideWithValue(db), initialSettingsProvider.overrideWithValue(settings)], child: const SolutionTeeApp()));
}
