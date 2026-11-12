import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

export 'community_data.dart' show agoText, communityError, checkNow;
export 'community_post.dart' show ComposeScreen, ThreadScreen;
export 'community_profile.dart' show CommunityEditScreen, FollowListScreen, ProfileView;
export 'community_shell.dart' show AllSubjectsScreen, CommunityShell, TagFeedScreen;

// Community (C15, D-151; v2 D-155): a full-screen space like X, with posts checked by the AI before others see them,
// @handles, photos (each student chooses, on by default), replies in threads, reposts and quotes, bookmarks, #topics,
// Explore, live notifications and profiles. Everything goes through community_* functions on the server.

/// Study card: the way in.
class CommunityCard extends ConsumerWidget {
  const CommunityCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AppCard(
      onTap: () => context.push('/community'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill), tone: Tone.blue, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community', style: context.ty.body.bold),
                const Gap(2),
                Text(
                  'Ask questions, share tips, learn with other students.',
                  style: context.ty.cap.col(c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
  }
}
