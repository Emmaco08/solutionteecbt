import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// Is the phone really online? (owner, 14 Nov 2026: a better no-internet mode.)
///
/// "Connected to Wi-Fi or mobile data" is not enough in Nigeria: data can run out while the phone still shows bars. So
/// when the phone says it is connected we make one tiny request to our server; while offline we check again every 10 s
/// (and at once when the network changes). While online we only re-check when the network changes, so no data is wasted.
final onlineProvider = StreamProvider<bool>((ref) {
  final out = StreamController<bool>();
  bool? last;
  Timer? retry;
  var disposed = false;

  Future<bool> reach() async {
    try {
      final r = await http.head(Uri.parse('${Config.supabaseUrl}/auth/v1/health')).timeout(const Duration(seconds: 5));
      return r.statusCode < 600;
    } catch (_) {
      return false;
    }
  }

  Future<void> check([List<ConnectivityResult>? net]) async {
    final n = net ?? await Connectivity().checkConnectivity().catchError((_) => const [ConnectivityResult.other]);
    final none = n.isEmpty || n.every((x) => x == ConnectivityResult.none);
    final ok = none ? false : await reach();
    if (disposed) return;
    if (ok != last) {
      last = ok;
      out.add(ok);
    }
    retry?.cancel();
    if (!ok) retry = Timer(const Duration(seconds: 10), check);
  }

  final sub = Connectivity().onConnectivityChanged.listen(check, onError: (_) {});
  check();
  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
    sub.cancel();
    out.close();
  });
  return out.stream;
});
