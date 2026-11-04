import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opening screens that live inside the bottom tabs (D-073).
///
/// Challenges, the winners wall and My winnings live inside the Test and Me tabs, so the tabs and a back button
/// always show. Inside the same tab we push (back returns here); from another tab or a full-screen page we go
/// there, so the tab's own history is built and back walks up to the tab's first screen.

/// Old links still in notifications (`/challenges/…`, `/winnings`, `/winners-wall`) → their place in the tabs.
String tabRoute(String route) {
  if (route == '/challenges' || (route.startsWith('/challenges/') && !route.endsWith('/play'))) return '/test$route';
  if (route == '/winners-wall') return '/test/winners-wall';
  if (route == '/winnings') return '/me/winnings';
  if (route == '/invite') return '/me/invite';
  if (route == '/xp') return '/me/xp';
  return route;
}

/// Which tab a path belongs to, or null for a full-screen page.
String? tabOf(String path) {
  const roots = ['/home', '/study', '/test', '/ai', '/me'];
  const nested = ['/test/challenges', '/test/winners-wall', '/me/winnings', '/me/invite', '/me/xp'];
  if (roots.contains(path)) return path;
  for (final n in nested) {
    if (path == n || path.startsWith('$n/')) return n.substring(0, n.indexOf('/', 1));
  }
  return null;
}

/// Opens [route] the right way for where we are now.
void openRoute(BuildContext context, String route) {
  final to = tabRoute(route);
  final tab = tabOf(Uri.parse(to).path);
  if (tab == null) {
    context.push(to);
    return;
  }
  String? here;
  try {
    here = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  } catch (_) {}
  if (here != null && tabOf(here) == tab) {
    context.push(to);
  } else {
    context.go(to);
  }
}
