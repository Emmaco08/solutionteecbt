import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/subject_icons.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../premium/paywall.dart';

/// Where each kind of study item opens.
String studyPath(String kind, String id) => switch (kind) {
  'video_solution' || 'lesson' => '/study/video/$id',
  'note' => '/study/note/$id',
  'novel' => '/study/novel/$id',
  _ => '/study/doc/$id',
};

/// Opens an item, or the paywall when the server marked it locked.
void openStudyItem(BuildContext context, Map<String, dynamic> it) {
  if (it['locked'] == true) {
    showPaywall(context, reason: it['kind'] as String?);
  } else {
    context.push(studyPath(it['kind'] as String, it['id'] as String));
  }
}

/// Subject name / code from its id (cached reference data).
String subjectName(WidgetRef ref, Object? id) => '${firstOr(ref.watch(subjectsProvider).value, (s) => s['id'] == id)['name'] ?? ''}';
String subjectCode(WidgetRef ref, Object? id) => '${firstOr(ref.watch(subjectsProvider).value, (s) => s['id'] == id)['code'] ?? ''}';

IconData kindIcon(String kind, [PhosphorIconsStyle s = PhosphorIconsStyle.fill]) => switch (kind) {
  'video_solution' => PhosphorIcons.playCircle(s),
  'lesson' => PhosphorIcons.chalkboardTeacher(s),
  'note' => PhosphorIcons.note(s),
  'novel' => PhosphorIcons.books(s),
  'doc' => PhosphorIcons.filePdf(s),
  _ => PhosphorIcons.exam(s),
};

/// Section icon names from app_settings.study_sections.
IconData sectionIcon(String name) => switch (name) {
  'playCircle' => PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
  'chalkboardTeacher' => PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill),
  'note' => PhosphorIcons.note(PhosphorIconsStyle.fill),
  'books' => PhosphorIcons.books(PhosphorIconsStyle.fill),
  'filePdf' => PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
  _ => PhosphorIcons.exam(PhosphorIconsStyle.fill),
};

Tone toneOf(String? name) => switch (name) {
  'blue' => Tone.blue,
  'gold' => Tone.gold,
  'green' => Tone.green,
  'red' => Tone.red,
  _ => Tone.navy,
};

/// Small round lock in a tile's corner (`.tile-lock`).
class TileLock extends StatelessWidget {
  const TileLock({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Premium',
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: context.c.surfaceSunken, shape: BoxShape.circle),
      child: Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 13, color: context.c.textMuted),
    ),
  );
}

/// "🔒 Premium" pill for locked rows.
class PremiumPill extends StatelessWidget {
  const PremiumPill({super.key});
  @override
  Widget build(BuildContext context) => Pill('Premium', kind: BadgeKind.neutral, icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill));
}

/// Study hub tile (`.study-tile`): tone icon, title, caption, optional lock.
class StudyTile extends StatelessWidget {
  const StudyTile({super.key, required this.icon, required this.tone, required this.title, required this.caption, this.locked = false, this.onTap});
  final IconData icon;
  final Tone tone;
  final String title, caption;
  final bool locked;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(Space.s4),
    child: SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconTile(icon, tone: tone, size: 44, radius: 12, iconSize: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(caption, style: context.ty.cap.col(context.c.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
          if (locked) const Positioned(top: -6, right: -6, child: TileLock()),
        ],
      ),
    ),
  );
}

const _thumbs = [
  [Palette.navy800, Palette.blue600],
  [Palette.blue700, Palette.blue400],
  [Palette.navy950, Palette.navy600],
  [Palette.gold700, Palette.gold400],
];

/// Video thumbnail (`.thumb.th-1…4`): gradient, faint subject icon, play (or lock) button, duration.
class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    required this.index,
    required this.subjectIcon,
    this.duration,
    this.locked = false,
    this.radius = Radii.md,
    this.big = false,
    this.coverKey,
    this.itemId,
    this.hd = false,
    this.showPlay = true,
  });
  final int index;

  /// The video's own thumbnail (R2 key from the catalog's meta.cover), drawn over the gradient once loaded.
  final String? coverKey, itemId;
  final bool hd, showPlay;
  final IconData subjectIcon;
  final String? duration;
  final bool locked, big;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final g = _thumbs[index % _thumbs.length];
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 10, top: 8, child: Icon(subjectIcon, size: 64, color: Colors.white.withValues(alpha: .18))),
            if (coverKey != null && itemId != null) ...[
              Positioned.fill(
                child: R2Image(imageKey: coverKey!, itemId: itemId),
              ),
              // Soft shade so the play button and labels stay readable on bright thumbnails.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x1A000000), Color(0x00000000), Color(0x59000000)],
                    ),
                  ),
                ),
              ),
            ],
            if (showPlay)
              Container(
                width: big ? 60 : 44,
                height: big ? 60 : 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle, boxShadow: context.shadow(2)),
                child: Icon(
                  locked ? PhosphorIcons.lockSimple(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
                  size: big ? 26 : 20,
                  color: Palette.navy900,
                ),
              ),
            if (duration != null && duration!.isNotEmpty)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xC706132B), borderRadius: BorderRadius.circular(6)),
                  child: Text(duration!, style: context.ty.cap.bold.col(Colors.white).copyWith(fontSize: 11)),
                ),
              ),
            if (hd)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xC706132B), borderRadius: BorderRadius.circular(6)),
                  child: Text('HD', style: context.ty.cap.bold.col(Colors.white).copyWith(fontSize: 11)),
                ),
              ),
            if (locked)
              Positioned(
                top: 8,
                right: 8,
                child: Pill('Premium', kind: BadgeKind.gold, icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill)),
              ),
          ],
        ),
      ),
    );
  }
}

const _covers = [
  [Palette.navy700, Palette.navy950],
  [Palette.blue500, Palette.blue900],
  [Palette.gold500, Palette.gold800],
];

/// Book cover (`.cover.c1…3`): 3:4 gradient with the title at the bottom.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.title, this.index = 0, this.width, this.coverKey, this.itemId});
  final String title;
  final int index;
  final double? width;

  /// The book's real cover from the admin (catalog meta.cover); the gradient with the title shows until it loads.
  final String? coverKey, itemId;
  @override
  Widget build(BuildContext context) {
    final g = _covers[index % _covers.length];
    final fg = index % _covers.length == 2 ? Palette.navy900 : const Color(0xFFF4F7FC);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: context.shadow(2),
            gradient: LinearGradient(colors: g, begin: const Alignment(-.4, -1), end: const Alignment(.4, 1)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title.replaceFirst('[SAMPLE] ', ''),
                    style: context.ty.sm.bold.col(fg).copyWith(height: 18 / 14),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (coverKey != null && itemId != null) R2Image(imageKey: coverKey!, itemId: itemId, decodeWidth: 480, semanticLabel: '$title cover'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subject filter chips (`.chips.filter`); null = all.
class SubjectChips extends ConsumerWidget {
  const SubjectChips({super.key, required this.subjectIds, required this.value, required this.onChanged, this.allLabel = 'All'});
  final List<int> subjectIds;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String allLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjectIds.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          AppChip(allLabel, on: value == null, onTap: () => onChanged(null)),
          for (final id in subjectIds) ...[const Gap(Space.s2), AppChip(subjectName(ref, id), on: value == id, onTap: () => onChanged(id))],
        ],
      ),
    );
  }
}

/// Subject ids present in a list of items, in the reference order.
List<int> subjectsIn(WidgetRef ref, Iterable<Map<String, dynamic>> items) {
  final present = {for (final i in items) (i['subject_id'] as num?)?.toInt()}..remove(null);
  return [
    for (final s in ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[])
      if (present.contains((s['id'] as num).toInt())) (s['id'] as num).toInt(),
  ];
}

IconData subjectIconFor(WidgetRef ref, Object? subjectId, [PhosphorIconsStyle s = PhosphorIconsStyle.fill]) => subjectIcon(subjectCode(ref, subjectId), s);

/// Strips the "[SAMPLE] " marker for display (sample rows stay recognisable in the admin).
String plainTitle(Object? t) => '${t ?? ''}'.replaceFirst('[SAMPLE] ', '');

/// A bookmark toggle for the top bar.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({super.key, required this.kind, required this.refId, required this.label});
  final String kind, refId, label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = (ref.watch(bookmarksProvider).value ?? const []).any((b) => b['kind'] == kind && b['ref'] == refId);
    return IconBtn(
      PhosphorIcons.bookmarkSimple(on ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
      label: on ? 'Remove bookmark' : 'Bookmark',
      color: on ? context.c.secondary : null,
      onPressed: () async {
        try {
          final now = await ref.read(studyRepoProvider).toggleBookmark(kind: kind, refId: refId, label: label);
          if (context.mounted) {
            toast(context, now ? 'Saved to bookmarks' : 'Removed from bookmarks', icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill));
          }
        } catch (e) {
          if (context.mounted) toast(context, '$e', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
        }
      },
    );
  }
}
