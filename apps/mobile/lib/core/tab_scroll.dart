import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One scroll controller per bottom tab (0 Home, 1 Study, 2 Test, 3 AI, 4 Me), so tapping the tab you are on scrolls
/// it back to the top (D-136). Each tab's main list uses its controller.
final tabScrollProvider = Provider.family<ScrollController, int>((ref, i) {
  final c = ScrollController();
  ref.onDispose(c.dispose);
  return c;
});

/// Scrolls a tab's main list to the top (smoothly; at once from far down).
void scrollTabToTop(WidgetRef ref, int tab) {
  final c = ref.read(tabScrollProvider(tab));
  if (!c.hasClients || c.positions.length != 1 || c.offset <= 0) return;
  if (c.offset > 3000) c.jumpTo(600);
  c.animateTo(0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
}
