import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../tutor/tutor_chat.dart' show broadcastPayload;
import '../tutor/tutor_live.dart';

// Community v2 data (D-155): every read and write goes through community_* functions on the server (RLS + checks there).

SupabaseClient get cdb => Supabase.instance.client;

typedef Json = Map<String, dynamic>;

Json asJson(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
List<Json> asList(Object? o) => [for (final x in (o as List? ?? const [])) asJson(x)];

Future<Object?> crpc(String fn, [Map<String, dynamic>? params]) => cdb.rpc(fn, params: params).timeout(const Duration(seconds: 15));

/// "now", "5m", "2h", "3d", "12 Nov".
String agoText(Object? iso, [DateTime? now]) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return dayText(d);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dayText(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String monthYear(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : '${_months[d.month - 1]} ${d.year}';
}

/// "9:41 am · 12 Nov 2026" on the post page.
String fullTime(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'} · ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// 1.2K style counts.
String countText(int n) => n < 1000
    ? '$n'
    : n < 10000
    ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K'
    : '${n ~/ 1000}K';

String communityError(Object? e) => switch ('$e') {
  'too_many' => 'You have posted a lot today. Please try again tomorrow.',
  'short' => 'Write something or add a photo first.',
  'long' => 'Posts can be up to 500 characters.',
  'off' => 'Community is paused for now.',
  'image' => 'That picture could not be used. Try another one.',
  'length' => 'Replies can be up to 500 characters.',
  'not_found' => 'This post is no longer available.',
  'quote_gone' => 'That post is no longer available to quote.',
  'format' => 'Use 3 to 20 small letters, numbers, _ or . (start with a letter or number).',
  'reserved' => 'That @handle is kept for SolutionTee. Please pick another.',
  'taken' => 'Someone already has that @handle. Try another.',
  'wait' => 'You can change your @handle once a month.',
  'bio_long' => 'Your bio can be up to 160 characters.',
  'banned' => 'Posting is paused for now because some of your posts broke the community guidelines.',
  _ => 'Something went wrong. Please try again.',
};

const offlineText = 'Could not reach SolutionTee. Check your internet and try again.';

/// Asks the server to check a post, reply or profile change right away (the server also checks within 2 minutes).
Future<String> checkNow(String kind, [Object? id]) async {
  try {
    final r = await cdb.functions.invoke('community', body: {'action': 'check', 'kind': kind, 'id': ?id?.toString()}).timeout(const Duration(seconds: 60));
    return '${(r.data as Map?)?['status'] ?? 'pending'}';
  } catch (_) {
    return 'pending';
  }
}

// ---------------------------------------------------------------- shared post state

/// Changes made on one screen (like, repost, bookmark, delete) show on every other screen at once.
class PostPatches extends Notifier<Map<String, Json>> {
  @override
  Map<String, Json> build() => const {};
  void patch(String id, Json changes) => state = {
    ...state,
    id: {...?state[id], ...changes},
  };
}

final postPatchesProvider = NotifierProvider<PostPatches, Map<String, Json>>(PostPatches.new);

/// People followed or unfollowed this session (id → following).
class FollowPatches extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};
  void set(String id, bool on) => state = {...state, id: on};
}

final followPatchesProvider = NotifierProvider<FollowPatches, Map<String, bool>>(FollowPatches.new);

/// Bumped after a new post, delete, block or profile change, so lists reload.
class CommunityTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final communityTickProvider = NotifierProvider<CommunityTick, int>(CommunityTick.new);

Future<Json> toggleLike(WidgetRef ref, Json p) => _toggle(ref, p, 'community_like', 'liked', 'likes');
Future<Json> toggleRepost(WidgetRef ref, Json p) => _toggle(ref, p, 'community_repost', 'reposted', 'reposts');

Future<Json> _toggle(WidgetRef ref, Json p, String fn, String flag, String count) async {
  final id = '${p['id']}';
  final cur = {...p, ...?ref.read(postPatchesProvider)[id]};
  final on = cur[flag] != true;
  final n = ((cur[count] as num?)?.toInt() ?? 0) + (on ? 1 : -1);
  final notifier = ref.read(postPatchesProvider.notifier)..patch(id, {flag: on, count: n < 0 ? 0 : n});
  try {
    final r = asJson(await crpc(fn, {'p_id': id}));
    if (r['ok'] == true) {
      notifier.patch(id, {flag: r[flag] == true, count: (r[count] as num?)?.toInt() ?? n});
      return r;
    }
  } catch (_) {}
  notifier.patch(id, {flag: cur[flag] == true, count: cur[count] ?? 0});
  return {'ok': false};
}

Future<bool> toggleBookmark(WidgetRef ref, Json p) async {
  final id = '${p['id']}';
  final cur = {...p, ...?ref.read(postPatchesProvider)[id]};
  final on = cur['bookmarked'] != true;
  final notifier = ref.read(postPatchesProvider.notifier)..patch(id, {'bookmarked': on});
  try {
    final r = asJson(await crpc('community_bookmark', {'p_id': id}));
    if (r['ok'] == true) {
      notifier.patch(id, {'bookmarked': r['bookmarked'] == true});
      return r['bookmarked'] == true;
    }
  } catch (_) {}
  notifier.patch(id, {'bookmarked': cur['bookmarked'] == true});
  return cur['bookmarked'] == true;
}

/// Follow a student, or a SolutionTee page when [page] is true.
Future<bool?> toggleFollow(WidgetRef ref, String user, bool now, {bool page = false}) async {
  final n = ref.read(followPatchesProvider.notifier)..set(user, !now);
  try {
    final r = asJson(await crpc(page ? 'community_page_follow' : 'community_follow', page ? {'p_page': user} : {'p_user': user}));
    if (r['ok'] == true) {
      n.set(user, r['following'] == true);
      return r['following'] == true;
    }
  } catch (_) {}
  n.set(user, now);
  return null;
}

// ---------------------------------------------------------------- paged lists

/// A list that loads 20 at a time with endless scroll; the first page is kept on the phone for offline use.
class Pager extends ChangeNotifier {
  Pager(this.load, {this.cacheKey, this.db, this.pageSize = 20});
  final Future<List<Json>> Function(int offset) load;
  final String? cacheKey;
  final AppDb? db;
  final int pageSize;

  List<Json> items = [];
  bool loading = false;
  bool more = true;
  bool offline = false;
  Object? error;
  bool started = false;
  DateTime? loadedAt;
  bool _disposed = false;

  Future<void> refresh() async {
    started = true;
    loading = true;
    error = null;
    _notify();
    try {
      final list = await load(0);
      items = list;
      more = list.length >= pageSize;
      offline = false;
      loadedAt = DateTime.now();
      if (cacheKey != null) unawaited(db?.kvSet(cacheKey!, jsonEncode(list)));
    } catch (e) {
      final old = cacheKey == null ? null : await db?.kvGet(cacheKey!);
      if (old != null && items.isEmpty) {
        items = asList(jsonDecode(old));
        offline = true;
        more = false;
      } else if (items.isEmpty) {
        error = e;
      } else {
        offline = true;
      }
    }
    loading = false;
    _notify();
  }

  Future<void> next() async {
    if (loading || !more || offline) return;
    loading = true;
    _notify();
    try {
      final list = await load(items.length);
      final seen = {for (final x in items) '${x['id']}'};
      items = [...items, ...list.where((x) => !seen.contains('${x['id']}'))];
      more = list.length >= pageSize;
    } catch (_) {
      more = false;
    }
    loading = false;
    _notify();
  }

  void remove(String id) {
    items = items.where((x) => '${x['id']}' != id).toList();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ---------------------------------------------------------------- me, unread, live notes

final communityMeProvider = FutureProvider<Json>((ref) async {
  ref.watch(communityTickProvider);
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'community:me:$uid', (s) => s.rpc('community_user'), asJson);
});

class Unread extends Notifier<int> {
  @override
  int build() => 0;
  void set(int n) => state = n;
  void bump() => state = state + 1;
}

final communityUnreadProvider = NotifierProvider<Unread, int>(Unread.new);

Future<void> loadUnread(WidgetRef ref) async {
  try {
    final n = await crpc('community_unread');
    ref.read(communityUnreadProvider.notifier).set((n as num?)?.toInt() ?? 0);
  } catch (_) {}
}

/// Live Community notes on the student's own private channel (`cnote:<id>`); calls [onNote] for each new one.
class NoteListener {
  NoteListener(this.uid, this.onNote);
  final String uid;
  final void Function(Json note) onNote;
  LiveChannel? _ch;
  ResumeWatcher? _resume;

  void open() {
    _ch = LiveChannel('cnote:$uid', private: true, (ch) => ch.onBroadcast(event: 'community_note', callback: (p) => onNote(broadcastPayload(p))))..open();
    _resume = ResumeWatcher(() => _ch?.restart());
  }

  void close() {
    _ch?.close();
    _resume?.dispose();
  }
}

/// Words for a note: "Tolu and 3 others liked your post".
String noteText(Json n) {
  final actors = asList(n['actors']);
  final count = (n['count'] as num?)?.toInt() ?? actors.length;
  final first = actors.isEmpty ? 'Someone' : '${actors.first['name']}';
  final who = count > 1 ? '$first and ${count - 1} ${count - 1 == 1 ? 'other' : 'others'}' : first;
  return switch ('${n['kind']}') {
    'like' => '$who liked your post',
    'repost' => '$who reposted your post',
    'comment_like' => '$who liked your reply',
    'reply' => '$first replied to you',
    'quote' => '$first quoted your post',
    'follow' => '$first followed you',
    'mention' => '$first mentioned you',
    'ai' => 'SolutionTee AI answered your question',
    'shown' => 'Your post is now shown to everyone',
    'rejected' => 'Your post was not shared',
    'profile' => '${n['body'] ?? 'Your profile was checked'}',
    'removed' => 'Your post was removed for breaking the community guidelines',
    'ban' => 'Posting is paused for a while',
    'post' => '$first just posted',
    'page' => 'New from SolutionTee',
    'milestone' => '${n['body'] ?? 'Your post is doing well'}',
    'digest' => 'Your day in Community',
    'suggest' => 'A question you might know',
    _ => 'New activity',
  };
}

/// "Posting is paused until 3:15 pm, 13 Nov".
String pausedText(Object? until) {
  final d = DateTime.tryParse('${until ?? ''}')?.toLocal();
  if (d == null) return communityError('banned');
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return 'Posting is paused until $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}, ${dayText(d)}, because some of your posts broke the community guidelines. You can still read and like posts.';
}

/// SolutionTee AI writes Markdown: a plain preview for small cards.
String plainPreview(String md) => md
    .replaceAll(RegExp(r'\*\*|__|`'), '')
    .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '• ')
    .replaceAll(RegExp(r'\n{2,}'), '\n')
    .trim();
