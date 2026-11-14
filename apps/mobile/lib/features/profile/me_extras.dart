import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../../core/platform.dart';

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
      photo: key == null || key.isEmpty ? null : R2Image.face(imageKey: key, decodeWidth: (size * 3).round(), semanticLabel: 'Profile photo'),
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
            if (!isDesktop) ListRow(icon: PhosphorIcons.camera(PhosphorIconsStyle.fill), title: 'Take a photo', onTap: () => Navigator.pop(ctx, 'camera')),
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
