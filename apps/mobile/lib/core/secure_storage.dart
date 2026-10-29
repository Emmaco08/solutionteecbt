import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase session in Android Keystore-backed encrypted storage (SECURITY.md §3).
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();
  static const _key = 'sb-session';
  final _s = const FlutterSecureStorage(aOptions: AndroidOptions());

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => (await _s.read(key: _key)) != null;
  @override
  Future<String?> accessToken() => _s.read(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) => _s.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _s.delete(key: _key);
}
