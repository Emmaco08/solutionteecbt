import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ads.dart';
import '../../core/nav.dart';
import '../../data/notifications_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';

/// Notifications (prototype `notifications`): filters, Today / Earlier, unread dots, mark all read, tap to open.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _cat = 'All';
  final Set<String> _readNow = {};

  (IconData, Tone) _look(String topic) => switch (topic) {
    'challenges' => (PhosphorIcons.trophy(PhosphorIconsStyle.fill), Tone.gold),
    'classes' => (PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), Tone.navy),
    'new_questions' => (PhosphorIcons.exam(PhosphorIconsStyle.fill), Tone.blue),
    'streak' => (PhosphorIcons.fire(PhosphorIconsStyle.fill), Tone.gold),
    'account' => (PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), Tone.green),
    _ => (PhosphorIcons.newspaper(PhosphorIconsStyle.fill), Tone.blue),
  };

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      setState(() => _readNow.add(n.id));
      ref.read(notificationsRepoProvider).markRead([n.id]).ignore();
    }
    final type = '${n.link['type'] ?? ''}', target = '${n.link['target'] ?? ''}';
    if (type == 'url' && target.startsWith('https://')) {
      await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
      return;
    }
    final route = linkRoute(n.link);
    if (route != null && mounted) openRoute(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(notificationsProvider);
    final all = [for (final n in async.value ?? const <AppNotification>[]) _readNow.contains(n.id) ? n.copyRead() : n];
    final unread = all.where((n) => !n.read).length;
    return Scaffold(
      appBar: TopBar(
        title: 'Notifications',
        subtitle: unread > 0 ? '$unread unread' : null,
        actions: [
          if (unread > 0)
            Btn(
              'Mark all read',
              kind: BtnKind.ghost,
              sm: true,
              onPressed: () {
                setState(() => _readNow.addAll(all.map((n) => n.id)));
                ref.read(notificationsRepoProvider).markRead(null).ignore();
                toast(context, 'All notifications marked as read', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
              },
            ),
          IconBtn(PhosphorIcons.gearSix(), label: 'Notification settings', onPressed: () => context.push('/settings')),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
              children: [
                for (final cat in const ['All', 'Challenges', 'Classes', 'Updates'])
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s2),
                    child: AppChip(
                      cat,
                      on: cat == _cat,
                      dot: cat != 'All' && all.any((n) => n.category == cat && !n.read),
                      onTap: () => setState(() => _cat = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: async.isLoading && all.isEmpty
                  ? const ListSkeleton(items: 6)
                  : async.hasError && all.isEmpty
                  ? asyncView(async, (_) => const SizedBox(), onRetry: () => ref.invalidate(notificationsProvider))
                  : _list(context, all.where((n) => _cat == 'All' || n.category == _cat).toList(), c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<AppNotification> list, AppColors c) {
    if (list.isEmpty) {
      return ListView(
        children: [
          StateBlock(
            icon: PhosphorIcons.bellSimple(PhosphorIconsStyle.fill),
            tone: Tone.blue,
            title: 'You are all caught up',
            text: _cat == 'All' ? 'We will let you know when something new happens.' : 'Nothing in $_cat yet. We will let you know when something new happens.',
          ),
        ],
      );
    }
    final now = DateTime.now();
    final today = list.where((n) => now.difference(n.sentAt).inHours < 24).toList();
    final earlier = list.where((n) => now.difference(n.sentAt).inHours >= 24).toList();
    final rm = context.reduceMotion;
    Widget group(String title, List<AppNotification> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.ty.label.col(c.textMuted)),
        const Gap(Space.s2),
        AppCard(
          pad: false,
          clip: true,
          child: Column(
            children: [
              for (final (i, n) in items.indexed) ...[if (i > 0) Divider(height: 1, color: c.border), _item(context, n, c)],
            ],
          ),
        ),
      ],
    );
    final groups = [if (today.isNotEmpty) group('Today', today), if (earlier.isNotEmpty) group('Earlier', earlier)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
      children: [
        const AdBanner(screen: 'notifications'),
        for (final (i, g) in groups.indexed) ...[
          if (i > 0) const Gap(Space.s5),
          rm ? g : g.animate(delay: Motion.stagger * i).fadeIn(duration: Motion.base).slideY(begin: .05, curve: Motion.out),
        ],
      ],
    );
  }

  Widget _item(BuildContext context, AppNotification n, AppColors c) {
    final (icon, tone) = _look(n.topic);
    return Semantics(
      button: true,
      label: '${n.read ? '' : 'Unread. '}${n.title}. ${n.body}',
      child: InkWell(
        onTap: () => _open(n),
        child: Container(
          color: n.read ? null : c.secondarySoft.withValues(alpha: .35),
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon, tone: tone, size: 40, radius: 10, iconSize: 20),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(n.title, style: context.ty.sm.bold)),
                        const Gap(Space.s2),
                        Text(agoText(n.sentAt), style: context.ty.cap.col(c.textSubtle)),
                      ],
                    ),
                    const Gap(2),
                    Text(n.body, style: context.ty.sm.col(c.textMuted)),
                  ],
                ),
              ),
              if (!n.read) ...[
                const Gap(Space.s2),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c.secondary, shape: BoxShape.circle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
