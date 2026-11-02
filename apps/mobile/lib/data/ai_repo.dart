import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/providers.dart';

/// SolutionTee AI tutor (milestone 4B, D-058). The phone talks only to the `ai-chat` Edge Function; model choice,
/// keys, quota and fallback all happen on the server.

/// Today's AI prompts: {used, limit, left, resets_at}.
final aiQuotaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(myPlanProvider);
  final j = await ref.read(supabaseProvider).rpc('ai_quota');
  return Map<String, dynamic>.from((j as Map?) ?? const {});
});

/// The student's chats, newest first (own rows only, RLS).
final aiChatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(sessionProvider);
  final j = await ref.read(supabaseProvider).from('ai_chats').select('id, title, subject_id, updated_at').order('updated_at', ascending: false).limit(100);
  return rows(j);
});

final aiRepoProvider = Provider<AiRepo>((ref) => AiRepo(ref));

/// One event from the tutor's stream.
sealed class AiEvent {}

class AiStart extends AiEvent {
  AiStart(this.chatId);
  final String chatId;
}

class AiThinking extends AiEvent {}

class AiDelta extends AiEvent {
  AiDelta(this.text);
  final String text;
}

class AiDone extends AiEvent {
  AiDone({this.messageId, this.left, this.model});
  final String? messageId, model;
  final int? left;
}

class AiFailed extends AiEvent {
  AiFailed(this.message, {this.code});
  final String message;
  final String? code; // quota | slow | busy | banned | auth | net
}

/// Turns Server-Sent Events text into [AiEvent]s. Lines may arrive split across network chunks.
class AiSseParser {
  final _buf = StringBuffer();
  List<AiEvent> add(String chunk) {
    _buf.write(chunk);
    final out = <AiEvent>[];
    var text = _buf.toString();
    int i;
    while ((i = text.indexOf('\n\n')) >= 0) {
      final block = text.substring(0, i);
      text = text.substring(i + 2);
      for (final line in block.split('\n')) {
        final l = line.trim();
        if (!l.startsWith('data:')) continue;
        final e = parse(l.substring(5).trim());
        if (e != null) out.add(e);
      }
    }
    _buf
      ..clear()
      ..write(text);
    return out;
  }

  static AiEvent? parse(String data) {
    try {
      final j = jsonDecode(data) as Map<String, dynamic>;
      return switch (j['t']) {
        'start' => AiStart('${j['chat_id']}'),
        'think' => AiThinking(),
        'd' => AiDelta('${j['c'] ?? ''}'),
        'done' => AiDone(messageId: j['message_id'] as String?, left: (j['left'] as num?)?.toInt(), model: j['model'] as String?),
        'error' => AiFailed('${j['message'] ?? 'Something went wrong. Try again.'}', code: j['code'] as String?),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

class AiRepo {
  AiRepo(this.ref);
  final Ref ref;
  SupabaseClient get _sb => ref.read(supabaseProvider);
  http.Client? _client;

  /// Asks the tutor. [imageBase64] is a JPEG already shrunk on the phone. Cancel by cancelling the subscription
  /// (or calling [stop]).
  Stream<AiEvent> ask({
    String? chatId,
    String text = '',
    String? imageBase64,
    int? subjectId,
    bool hint = false,
    String? questionId,
    bool explain = false,
  }) async* {
    final token = _sb.auth.currentSession?.accessToken;
    if (token == null) {
      yield AiFailed('Please log in again.', code: 'auth');
      return;
    }
    final client = _client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('${Config.supabaseUrl}/functions/v1/ai-chat'))
        ..headers.addAll({'authorization': 'Bearer $token', 'apikey': Config.supabasePublishableKey, 'content-type': 'application/json'})
        ..body = jsonEncode({
          'chat_id': ?chatId,
          'text': text,
          'image': ?imageBase64,
          'subject_id': ?subjectId,
          'hint': hint,
          'question_id': ?questionId,
          'explain': explain,
        });
      final res = await client.send(req).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) {
        final body = await res.stream.bytesToString();
        Map<String, dynamic> j = const {};
        try {
          j = jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {}
        yield AiFailed(
          '${j['error'] ?? 'SolutionTee AI is not available right now. Try again.'}',
          code: j['code'] as String? ?? (res.statusCode == 401 ? 'auth' : null),
        );
        return;
      }
      final parser = AiSseParser();
      await for (final chunk in res.stream.transform(utf8.decoder).timeout(const Duration(seconds: 90))) {
        for (final e in parser.add(chunk)) {
          yield e;
        }
      }
    } on TimeoutException {
      yield AiFailed('The connection is too slow. Check your data and try again.', code: 'net');
    } on ApiError catch (e) {
      yield AiFailed(e.message, code: 'net');
    } catch (_) {
      yield AiFailed('No internet connection. Check your data or Wi-Fi and try again.', code: 'net');
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      ref.invalidate(aiQuotaProvider);
      ref.invalidate(aiChatsProvider);
    }
  }

  /// Stops the answer that is coming in (the prompt still counts once the server started answering).
  void stop() {
    _client?.close();
    _client = null;
  }

  Future<List<Map<String, dynamic>>> messages(String chatId) async {
    final j = await _sb
        .from('ai_messages')
        .select('id, role, content, has_image, question_id, hint, model, flagged_at, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .limit(200);
    return rows(j);
  }

  Future<void> deleteChat(String chatId) async {
    await _sb.from('ai_chats').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', chatId);
    ref.invalidate(aiChatsProvider);
  }

  Future<void> flag(String messageId, String reason) => _sb.rpc('ai_flag', params: {'p_message': messageId, 'p_reason': reason});
}
