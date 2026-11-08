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

/// Server-made suggestion chips. Invalidated after each answer so they follow what the student just did.
final aiSuggestionsProvider = FutureProvider<List<AiChip>>((ref) async {
  ref.watch(sessionProvider);
  return ref.read(aiRepoProvider).suggestions();
});

/// The active study plan's part for today (Home "Today" card): null, or {plan_id, title, day, of, done, reminders, item}.
final todayPlanProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(sessionProvider);
  final j = await ref.read(supabaseProvider).rpc('my_today_plan');
  return j is Map ? Map<String, dynamic>.from(j) : null;
});

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
  AiDone({this.messageId, this.left, this.model, this.free = false, this.next = const []});
  final String? messageId, model;
  final int? left;

  /// The next steps of a request with several steps ("check my weak topics, then make a plan…"): {tool, args, label}.
  final List<Map<String, dynamic>> next;

  /// True when no prompt was used (a tool the server answered by itself).
  final bool free;
}

/// A tool the tutor is running (state `run`, with a [label]) or has finished (state `done`, with a [card] or null).
class AiTool extends AiEvent {
  AiTool(this.name, this.state, {this.label, this.card, this.steps = const []});
  final String name, state;
  final String? label;

  /// The steps the app animates while the tool works (run event only).
  final List<String> steps;
  final Map<String, dynamic>? card;
  bool get running => state == 'run';
}

/// Three "what next?" questions the tutor wrote after an answer.
class AiFollowups extends AiEvent {
  AiFollowups(this.items);
  final List<String> items;
}

/// One suggestion chip: show [label]; tapping sends [text] (or the label) and, when set, runs [tool] with [args].
/// [icon] is a server icon name; a chip with [chatId] opens that chat instead.
class AiChip {
  const AiChip(this.label, {this.text, this.tool, this.args = const {}, this.icon, this.chatId});
  final String label;
  final String? text, tool, icon, chatId;
  final Map<String, dynamic> args;
  factory AiChip.fromJson(Map<String, dynamic> j) => AiChip(
    '${j['label'] ?? ''}',
    text: j['text'] as String?,
    tool: j['tool'] as String?,
    args: j['args'] is Map ? Map<String, dynamic>.from(j['args'] as Map) : const {},
    icon: j['icon'] as String?,
    chatId: j['chat_id'] as String?,
  );
}

class AiFailed extends AiEvent {
  AiFailed(this.message, {this.code});
  final String message;
  final String? code; // quota | slow | busy | banned | auth | net | locked
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
        'done' => AiDone(
          messageId: j['message_id'] as String?,
          left: (j['left'] as num?)?.toInt(),
          model: j['model'] as String?,
          free: j['free'] == true,
          next: [
            for (final x in (j['next'] as List? ?? const []))
              if (x is Map) Map<String, dynamic>.from(x),
          ],
        ),
        'tool' => AiTool(
          '${j['name'] ?? ''}',
          '${j['state'] ?? ''}',
          label: j['label'] as String?,
          card: j['card'] is Map ? Map<String, dynamic>.from(j['card'] as Map) : null,
          steps: [for (final x in (j['steps'] as List? ?? const [])) '$x'],
        ),
        'followups' => AiFollowups([for (final x in (j['items'] as List? ?? const [])) '$x']),
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
    int? hintLevel,
    String? questionId,
    bool explain = false,
    String? tool,
    Map<String, dynamic>? args,
    bool readFirst = false,
    List<Map<String, dynamic>>? then,
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
          'hint_level': ?(hint ? hintLevel : null),
          'question_id': ?questionId,
          'explain': explain,
          'tool': ?tool,
          'args': ?args,
          'read_first': ?(imageBase64 != null && readFirst ? true : null),
          'then': ?(then == null || then.isEmpty ? null : then),
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
    final recent = _sb
        .from('ai_messages')
        .select('id, role, content, has_image, question_id, hint, model, flagged_at, created_at, card, reaction')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .limit(200);
    // Messages older than the archive window live in Neon (D-108): asked for only when the chat itself is old.
    final chat = await _sb.from('ai_chats').select('created_at').eq('id', chatId).maybeSingle();
    final created = DateTime.tryParse('${chat?['created_at'] ?? ''}');
    final old = created != null && DateTime.now().difference(created).inDays >= 13;
    final results = await Future.wait<List<Map<String, dynamic>>>([recent.then(rows), if (old) _archived(chatId)]);
    if (results.length == 1) return results.first;
    final seen = <String>{};
    final all = [
      for (final m in [...results[1], ...results[0]])
        if (seen.add('${m['id']}')) m,
    ]..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    return all;
  }

  Future<List<Map<String, dynamic>>> _archived(String chatId) async {
    try {
      final r = await _sb.functions.invoke('archive-read', body: {'kind': 'chat', 'chat_id': chatId}).timeout(const Duration(seconds: 8));
      final d = r.data;
      return d is Map ? rows(d['messages']) : const [];
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> get _headers => {
    'authorization': 'Bearer ${_sb.auth.currentSession?.accessToken ?? ''}',
    'apikey': Config.supabasePublishableKey,
    'content-type': 'application/json',
  };

  Future<Map<String, dynamic>?> _action(Map<String, dynamic> body) async {
    if (_sb.auth.currentSession?.accessToken == null) return null;
    final res = await http
        .post(Uri.parse('${Config.supabaseUrl}/functions/v1/ai-chat'), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  /// Suggestion chips made by the server (no prompt used). Empty on any error: the screen then shows its own list.
  Future<List<AiChip>> suggestions() async {
    try {
      final j = await _action({'action': 'suggest'});
      final list = (j?['chips'] as List?) ?? const [];
      return [
        for (final c in list)
          if (c is Map && '${c['label'] ?? ''}'.isNotEmpty) AiChip.fromJson(Map<String, dynamic>.from(c)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Marks one quiz answer on the server (free): {ok, correct, answer, explanation}. `{ok:false}` on any error.
  Future<Map<String, dynamic>> quizCheck(String questionId, String choice) async {
    try {
      return await _action({'action': 'quiz_check', 'question_id': questionId, 'choice': choice}) ?? const {'ok': false};
    } catch (_) {
      return const {'ok': false};
    }
  }

  /// Cancels a reminder the AI set (big update 2, A1).
  Future<bool> cancelReminder(String id) async {
    try {
      final r = await _action({'action': 'reminder_cancel', 'id': id});
      return r?['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteChat(String chatId) async {
    await _sb.from('ai_chats').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', chatId);
    ref.invalidate(aiChatsProvider);
  }

  /// Ticks a study-plan day and/or switches the morning reminder.
  Future<void> planUpdate(String planId, {int? doneDay, bool? reminders}) async {
    await _sb.rpc('plan_update', params: {'p_plan': planId, 'p_done_day': ?doneDay, 'p_reminders': ?reminders});
    ref.invalidate(todayPlanProvider);
  }

  /// Saves (or, with null, removes) a reaction on a tutor answer.
  Future<void> react(String messageId, String? reaction) => _sb.rpc('ai_react', params: {'p_message': messageId, 'p_reaction': reaction});

  Future<void> flag(String messageId, String reason) => _sb.rpc('ai_flag', params: {'p_message': messageId, 'p_reason': reason});
}
