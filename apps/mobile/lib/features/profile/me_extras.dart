import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';

/// The 8 badges of the approved design (server `my_badges`), cached for offline.
final myBadgesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'badges:$uid', (s) => s.rpc('my_badges'), rows);
});

/// The student's avatar: their photo when they added one, else initials (prototype `.avatar`).
class MyAvatar extends ConsumerWidget {
  const MyAvatar(this.name, {super.key, this.size = 44});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(profileProvider).value?['avatar_path'] as String?;
    return Avatar(
      name,
      size: size,
      photo: key == null || key.isEmpty ? null : R2Image(imageKey: key, decodeWidth: (size * 3).round(), semanticLabel: 'Profile photo'),
    );
  }
}

/// Profile photo sheet (prototype `#avEdit`): take a photo, choose one, or remove it. The photo is shrunk on the
/// phone (512 px JPEG) and uploaded to the private bucket through a 10-minute link from the website (D-063).
Future<void> showPhotoSheet(BuildContext context, WidgetRef ref) async {
  final has = (ref.read(profileProvider).value?['avatar_path'] as String?)?.isNotEmpty ?? false;
  final pick = await showSheet<String>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Profile photo', style: ctx.ty.h3),
        const Gap(Space.s2),
        Text('Only you can see your photo for now.', style: ctx.ty.sm.col(ctx.c.textMuted)),
        const Gap(Space.s4),
        ListCard(
          children: [
            ListRow(icon: PhosphorIcons.camera(PhosphorIconsStyle.fill), title: 'Take a photo', onTap: () => Navigator.pop(ctx, 'camera')),
            ListRow(icon: PhosphorIcons.image(PhosphorIconsStyle.fill), title: 'Choose from gallery', onTap: () => Navigator.pop(ctx, 'gallery')),
            if (has)
              ListRow(icon: PhosphorIcons.trash(PhosphorIconsStyle.fill), title: 'Remove photo', danger: true, onTap: () => Navigator.pop(ctx, 'remove')),
          ],
        ),
      ],
    ),
  );
  if (pick == null || !context.mounted) return;
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return;
  try {
    if (pick == 'remove') {
      await sb.from('profiles').update({'avatar_path': null}).eq('id', uid);
      ref.invalidate(profileProvider);
      if (context.mounted) toast(context, 'Profile photo removed', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
      return;
    }
    final x = await ImagePicker().pickImage(
      source: pick == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x == null || !context.mounted) return;
    final bytes = await File(x.path).readAsBytes();
    if (bytes.length > 1024 * 1024) throw Exception('too big');
    if (context.mounted) toast(context, 'Saving your photo…', icon: PhosphorIcons.cloudArrowUp(PhosphorIconsStyle.fill));
    final (key, url) = await ref.read(apiProvider).avatarUploadLink(bytes.length);
    final r = await http.put(Uri.parse(url), headers: {'content-type': 'image/jpeg'}, body: bytes).timeout(const Duration(seconds: 60));
    if (r.statusCode >= 300) throw Exception('upload ${r.statusCode}');
    await sb.from('profiles').update({'avatar_path': key}).eq('id', uid);
    ref.invalidate(profileProvider);
    if (context.mounted) toast(context, 'Profile photo saved', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
  } catch (_) {
    if (context.mounted) toast(context, 'Could not save the photo. Check your internet and try again.');
  }
}

/// Badges (prototype `.badge-tile`): the 8 from the design, earned ones in colour, the rest faded with what is left.
class BadgesSection extends ConsumerWidget {
  const BadgesSection({super.key});

  static (IconData, Tone) look(String key) => switch (key) {
    'streak7' => (PhosphorIcons.fire(PhosphorIconsStyle.fill), Tone.gold),
    'first250' => (PhosphorIcons.target(PhosphorIconsStyle.fill), Tone.blue),
    'speedster' => (PhosphorIcons.lightning(PhosphorIconsStyle.fill), Tone.navy),
    'correct100' => (PhosphorIcons.star(PhosphorIconsStyle.fill), Tone.gold),
    'score300' => (PhosphorIcons.trophy(PhosphorIconsStyle.fill), Tone.gold),
    'nightowl' => (PhosphorIcons.moonStars(PhosphorIconsStyle.fill), Tone.navy),
    'bookworm' => (PhosphorIcons.books(PhosphorIconsStyle.fill), Tone.green),
    _ => (PhosphorIcons.medal(PhosphorIconsStyle.fill), Tone.blue),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final badges = ref.watch(myBadgesProvider).value;
    if (badges == null || badges.isEmpty) return const SizedBox.shrink();
    final earned = badges.where((b) => b['earned'] == true).length;
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: Row(
            children: [
              Expanded(child: Text('Badges', style: context.ty.h3)),
              Text('$earned of ${badges.length}', style: context.ty.cap.col(c.textMuted)),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.s2,
          crossAxisSpacing: Space.s2,
          childAspectRatio: .8,
          children: [
            for (final (i, b) in badges.indexed)
              _tile(
                context,
                b,
                c,
              ).animate(target: rm ? 0 : 1).fadeIn(delay: (30 * i).ms, duration: Motion.base).scale(begin: const Offset(.9, .9), end: const Offset(1, 1)),
          ],
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> b, AppColors c) {
    final on = b['earned'] == true;
    final (icon, tone) = look('${b['key']}');
    return Tooltip(
      message: on ? '${b['title']}: earned' : '${b['title']}: ${b['progress'] ?? ''}',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '${b['title']}, ${on ? 'earned' : 'not yet'}',
        child: Opacity(
          opacity: on ? 1 : .45,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTile(icon, tone: on ? tone : Tone.neutral, size: 48, radius: 24, iconSize: 24),
              const Gap(Space.s1),
              Text('${b['title']}', style: context.ty.cap.bold, textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
