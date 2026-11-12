import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/fit_text.dart';
import '../../widgets/r2_image.dart';
import 'community_data.dart';

// Community v2 building blocks (D-155): avatar, rich text, pictures, quote card, actions with the like burst, the post cell.

const kLike = Color(0xFFF43F6B);
Color repostColor(BuildContext c) => c.isDark ? const Color(0xFF3DDC84) : Palette.green600;

/// Initials in a coloured circle, the student's photo over them when they chose to show it (on by default).
class CAvatar extends StatelessWidget {
  const CAvatar({super.key, required this.name, this.photo, this.size = 44, this.ai = false, this.onTap, this.ring, this.brand = false});
  final String name;
  final String? photo;
  final double size;
  final bool ai;

  /// The official SolutionTee page: the logo (unless the page has its own photo).
  final bool brand;
  final VoidCallback? onTap;
  final Color? ring;

  static const _tones = [Palette.blue600, Palette.green500, Palette.gold400, Palette.blue400, Palette.navy600, Palette.amber500];

  @override
  Widget build(BuildContext context) {
    Widget a;
    if (ai || (brand && (photo == null || photo!.isEmpty))) {
      a = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .28)),
        child: const Mark(onDark: false),
      );
    } else {
      final bg = _tones[name.codeUnits.fold<int>(0, (s, x) => s + x) % _tones.length];
      final fg = bg == Palette.gold400 || bg == Palette.blue400 ? Palette.navy900 : Colors.white;
      final has = photo != null && photo!.isNotEmpty;
      a = Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: ring != null ? Border.all(color: ring!, width: size > 60 ? 4 : 2) : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(Avatar.initials(name), style: context.ty.label.bold.copyWith(fontSize: size * .32, height: 1).col(fg)),
            ),
            if (has) R2Image.face(imageKey: photo!, decodeWidth: (size * 3).round(), semanticLabel: name),
          ],
        ),
      );
    }
    if (onTap == null) return a;
    return Semantics(
      button: true,
      label: '$name profile',
      child: GestureDetector(onTap: onTap, child: a),
    );
  }
}

/// The SolutionTee AI badge (gold seal).
class AiSeal extends StatelessWidget {
  const AiSeal({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: size, color: Palette.gold400, semanticLabel: 'SolutionTee');
}

/// Post text: maths with $...$, #topics and @handles you can tap, @solutiontee in gold.
class CText extends StatefulWidget {
  const CText(this.text, {super.key, this.style, this.maxLines});
  final String text;
  final TextStyle? style;
  final int? maxLines;
  @override
  State<CText> createState() => _CTextState();
}

class _CTextState extends State<CText> {
  final _taps = <TapGestureRecognizer>[];
  static final _re = RegExp(r'(#[A-Za-z][A-Za-z0-9_]{1,29})|(@[A-Za-z0-9][A-Za-z0-9_.]{1,18}[A-Za-z0-9_])');

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(String s) {
    final c = context.c;
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _re.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final word = m.group(0)!;
      final ai = word.toLowerCase() == '@solutiontee';
      final t = TapGestureRecognizer()
        ..onTap = () {
          if (ai) return;
          if (word.startsWith('#')) {
            context.push('/community/tag/${Uri.encodeComponent(word.substring(1))}');
          } else {
            context.push('/community/u/${Uri.encodeComponent(word.substring(1).toLowerCase())}');
          }
        };
      _taps.add(t);
      out.add(
        TextSpan(
          text: word,
          recognizer: t,
          style: TextStyle(color: ai ? (context.isDark ? Palette.gold400 : Palette.gold700) : c.link, fontWeight: ai ? FontWeight.w700 : null),
        ),
      );
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final text = MathText(widget.text, style: widget.style ?? context.ty.body, plain: _spans);
    if (widget.maxLines == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxLines! * ((widget.style ?? context.ty.body).fontSize ?? 15) * 1.45),
      child: ClipRect(child: text),
    );
  }
}

// ---------------------------------------------------------------- pictures

/// Up to 4 pictures in the X layouts; tap for full screen. With data saver on, they load only when tapped.
class ImageGrid extends ConsumerStatefulWidget {
  const ImageGrid({super.key, required this.keys, this.height = 200});
  final List<String> keys;
  final double height;
  @override
  ConsumerState<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<ImageGrid> {
  bool _show = false;

  Widget _tile(int i) {
    final c = context.c;
    return GestureDetector(
      onTap: () => openViewer(context, widget.keys, i),
      child: Container(
        color: c.surfaceSunken,
        child: Hero(
          tag: 'cimg:${widget.keys[i]}',
          child: R2Image(imageKey: widget.keys[i], decodeWidth: 640, semanticLabel: 'Picture ${i + 1} of ${widget.keys.length}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.keys;
    if (k.isEmpty) return const SizedBox.shrink();
    final c = context.c;
    final saver = ref.watch(settingsProvider).dataSaver;
    if (saver && !_show) {
      return Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => setState(() => _show = true),
          child: Container(
            height: 64,
            decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.image(), color: c.textMuted, size: 20),
                const Gap(Space.s2),
                Text('Tap to load ${k.length == 1 ? 'the picture' : '${k.length} pictures'} (data saver)', style: context.ty.sm.col(c.textMuted)),
              ],
            ),
          ),
        ),
      );
    }
    const g = 3.0;
    final Widget grid = switch (k.length) {
      1 => AspectRatio(aspectRatio: 16 / 11, child: _tile(0)),
      2 => SizedBox(
        height: widget.height,
        child: Row(
          children: [
            Expanded(child: _tile(0)),
            const SizedBox(width: g),
            Expanded(child: _tile(1)),
          ],
        ),
      ),
      3 => SizedBox(
        height: widget.height,
        child: Row(
          children: [
            Expanded(child: _tile(0)),
            const SizedBox(width: g),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(1)),
                  const SizedBox(height: g),
                  Expanded(child: _tile(2)),
                ],
              ),
            ),
          ],
        ),
      ),
      _ => SizedBox(
        height: widget.height,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(0)),
                  const SizedBox(width: g),
                  Expanded(child: _tile(1)),
                ],
              ),
            ),
            const SizedBox(height: g),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(2)),
                  const SizedBox(width: g),
                  Expanded(child: _tile(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: grid,
      ),
    );
  }
}

void openViewer(BuildContext context, List<String> keys, int start) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: Motion.base,
    pageBuilder: (_, a, _) => FadeTransition(
      opacity: a,
      child: _Viewer(keys: keys, start: start),
    ),
  ),
);

class _Viewer extends StatefulWidget {
  const _Viewer({required this.keys, required this.start});
  final List<String> keys;
  final int start;
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        PageView.builder(
          controller: _pc,
          itemCount: widget.keys.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Hero(
                tag: 'cimg:${widget.keys[i]}',
                child: R2Image(imageKey: widget.keys[i], fit: BoxFit.contain, decodeWidth: 1440, semanticLabel: 'Picture ${i + 1}'),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.s2),
            child: Row(
              children: [
                IconBtn(PhosphorIcons.x(), label: 'Close', color: Colors.white, glass: true, onPressed: () => Navigator.pop(context)),
                const Spacer(),
                if (widget.keys.length > 1) Text('${_i + 1} / ${widget.keys.length}', style: context.ty.sm.bold.col(Colors.white)),
                const Gap(Space.s4),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- quote and AI answer

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.q, this.onTap});
  final Json q;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (q['unavailable'] == true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Text('This post is no longer available.', style: context.ty.sm.col(c.textMuted)),
      );
    }
    final imgs = [for (final x in (q['images'] as List? ?? const [])) '$x'];
    return GestureDetector(
      onTap: onTap ?? () => context.push('/community/post/${q['id']}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Space.s3, 10, Space.s3, Space.s3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CAvatar(name: '${q['name']}', photo: q['avatar_path'] as String?, size: 20),
                const Gap(6),
                Expanded(
                  child: NameLine(
                    name: '${q['name']}',
                    nameStyle: context.ty.sm.bold,
                    handle: '${q['handle']}',
                    time: agoText(q['created_at']),
                    metaStyle: context.ty.sm.col(c.textMuted),
                  ),
                ),
              ],
            ),
            const Gap(4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CText('${q['body'] ?? ''}', style: context.ty.sm.col(c.textMuted), maxLines: 4)),
                if (imgs.isNotEmpty) ...[
                  const Gap(Space.s2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: SizedBox(width: 56, height: 56, child: R2Image(imageKey: imgs.first, decodeWidth: 168)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AiAnswerCard extends StatelessWidget {
  const AiAnswerCard({super.key, required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CAvatar(name: 'SolutionTee AI', ai: true, size: 22),
                const Gap(6),
                Flexible(
                  child: Text('SolutionTee AI', style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Gap(4),
                const AiSeal(size: 14),
                const Gap(4),
                Flexible(
                  child: Text('answered', style: context.ty.sm.col(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Gap(6),
            CText(plainPreview(text), style: context.ty.sm.col(c.textMuted), maxLines: 4),
            const Gap(6),
            Text('Read the full answer', style: context.ty.sm.bold.col(c.link)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- author-only states

class CheckingNote extends StatelessWidget {
  const CheckingNote({super.key, this.text = 'Being checked. Only you can see it for now; it usually takes a few seconds.'});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 10),
      decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: context.reduceMotion
                ? Icon(PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill), size: 16, color: c.onSecondarySoft)
                : CircularProgressIndicator(strokeWidth: 2.5, color: c.onSecondarySoft),
          ),
          const Gap(10),
          Expanded(child: Text(text, style: context.ty.sm.col(c.onSecondarySoft))),
        ],
      ),
    );
  }
}

class NotShownNote extends StatelessWidget {
  const NotShownNote({super.key, required this.reason, this.onDelete});
  final String? reason;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 10),
      decoration: BoxDecoration(
        color: c.errorSoft,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.error.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.prohibit(), size: 16, color: c.onErrorSoft),
              const Gap(Space.s2),
              Text('Not shown', style: context.ty.sm.bold.col(c.onErrorSoft)),
            ],
          ),
          const Gap(4),
          Text(reason?.isNotEmpty == true ? reason! : 'It does not follow the community rules.', style: context.ty.sm.col(c.onErrorSoft)),
          if (onDelete != null)
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), foregroundColor: c.onErrorSoft),
              child: Text('Delete post', style: context.ty.sm.bold),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- actions

/// One action under a post: icon and a count that rolls when it changes.
class ActionBtn extends StatelessWidget {
  const ActionBtn({super.key, required this.icon, required this.label, this.count, this.color, this.onTap, this.child});
  final IconData icon;
  final String label;
  final int? count;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final col = color ?? context.c.textMuted;
    final rm = context.reduceMotion;
    return Semantics(
      button: true,
      label: count != null ? '$label, $count' : label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                child ?? Icon(icon, size: 19, color: col),
                if (count != null && count! > 0) ...[
                  const Gap(4),
                  AnimatedSwitcher(
                    duration: rm ? Duration.zero : Motion.fast,
                    transitionBuilder: (w, a) => ClipRect(
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(a),
                        child: FadeTransition(opacity: a, child: w),
                      ),
                    ),
                    child: Text(countText(count!), key: ValueKey(count), style: context.ty.cap.tnum.col(col)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The heart with a small burst of dots when liked (off with reduce motion).
class HeartIcon extends StatefulWidget {
  const HeartIcon({super.key, required this.on, this.size = 19});
  final bool on;
  final double size;
  @override
  State<HeartIcon> createState() => _HeartIconState();
}

class _HeartIconState extends State<HeartIcon> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(HeartIcon old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on && !MediaQuery.of(context).disableAnimations) _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.on ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
      size: widget.size,
      color: widget.on ? kLike : context.c.textMuted,
    );
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        final t = _a.value;
        final scale = t == 0 ? 1.0 : (t < .35 ? 1 + .45 * Curves.easeOut.transform(t / .35) : 1.45 - .45 * Curves.elasticOut.transform((t - .35) / .65));
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (t > 0 && t < 1) Positioned.fill(child: CustomPaint(painter: _Burst(t))),
              Transform.scale(scale: scale, child: child),
            ],
          ),
        );
      },
      child: icon,
    );
  }
}

class _Burst extends CustomPainter {
  _Burst(this.t);
  final double t;
  static const _cols = [kLike, Palette.gold400, Palette.blue400, kLike, Palette.green500, Palette.gold400];
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final p = Curves.easeOut.transform(t);
    // A ring that grows and fades, then 6 dots flying out.
    canvas.drawCircle(
      c,
      s.width * (.3 + .55 * p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - p)
        ..color = kLike.withValues(alpha: (1 - p) * .7),
    );
    for (var i = 0; i < 6; i++) {
      final ang = i * math.pi / 3 - math.pi / 2;
      final r = s.width * (.45 + .6 * p);
      canvas.drawCircle(c + Offset(math.cos(ang) * r, math.sin(ang) * r), 2.2 * (1 - p) + .4, Paint()..color = _cols[i].withValues(alpha: 1 - p));
    }
  }

  @override
  bool shouldRepaint(_Burst o) => o.t != t;
}

/// Reply · Repost · Like · Bookmark · Share.
class PostActions extends ConsumerWidget {
  const PostActions({super.key, required this.post, this.onReply, this.big = false});
  final Json post;
  final VoidCallback? onReply;
  final bool big;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = {...post, ...?ref.watch(postPatchesProvider.select((m) => m['${post['id']}']))};
    final c = context.c;
    final liked = p['liked'] == true;
    final rp = p['reposted'] == true;
    final bm = p['bookmarked'] == true;
    final row = [
      ActionBtn(
        icon: PhosphorIcons.chatCircle(),
        label: 'Reply',
        count: big ? null : (p['comments'] as num?)?.toInt(),
        onTap: onReply ?? () => context.push('/community/post/${p['id']}?reply=1'),
      ),
      ActionBtn(
        icon: PhosphorIcons.repeat(),
        label: rp ? 'Undo repost' : 'Repost',
        count: big ? null : (p['reposts'] as num?)?.toInt(),
        color: rp ? repostColor(context) : null,
        onTap: () => showRepostSheet(context, ref, p),
      ),
      ActionBtn(
        icon: PhosphorIcons.heart(),
        label: liked ? 'Unlike' : 'Like',
        count: big ? null : (p['likes'] as num?)?.toInt(),
        color: liked ? kLike : null,
        onTap: () {
          HapticFeedback.lightImpact();
          toggleLike(ref, p);
        },
        child: HeartIcon(on: liked, size: big ? 22 : 19),
      ),
      ActionBtn(
        icon: bm ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill) : PhosphorIcons.bookmarkSimple(),
        label: bm ? 'Remove bookmark' : 'Bookmark',
        color: bm ? (context.isDark ? Palette.gold400 : Palette.gold600) : null,
        onTap: () async {
          HapticFeedback.selectionClick();
          final on = await toggleBookmark(ref, p);
          if (context.mounted) {
            toast(context, on ? 'Saved to your bookmarks' : 'Removed from bookmarks', icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill));
          }
        },
      ),
      ActionBtn(icon: PhosphorIcons.uploadSimple(), label: 'Share', onTap: () => sharePost(p)),
    ];
    return IconTheme(
      data: IconThemeData(color: c.textMuted),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: row),
    );
  }
}

void sharePost(Json p) {
  final body = '${p['body'] ?? ''}'.trim();
  SharePlus.instance.share(
    ShareParams(
      text:
          '${body.length > 240 ? '${body.substring(0, 240)}…' : body}\n\n— @${p['handle']} on SolutionTee CBT Community. Learn. Think. Solve.\nhttps://cbt.solutiontee.com',
    ),
  );
}

/// Repost (or undo) and Quote, as in the design.
Future<void> showRepostSheet(BuildContext context, WidgetRef ref, Json p) async {
  final rp = p['reposted'] == true;
  final c = context.c;
  final pick = await showSheet<String>(
    context,
    closeButton: false,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetOption(
          icon: PhosphorIcons.repeat(),
          tone: repostColor(ctx),
          bg: ctx.isDark ? const Color(0xFF0F3B26) : Palette.green50,
          title: rp ? 'Undo repost' : 'Repost',
          text: rp ? 'Take it off your profile' : 'Share it with your followers as it is',
          onTap: () => Navigator.pop(ctx, 'repost'),
        ),
        _SheetOption(
          icon: PhosphorIcons.pencilSimple(),
          tone: c.link,
          bg: c.secondarySoft,
          title: 'Quote',
          text: 'Add your own words above it',
          onTap: () => Navigator.pop(ctx, 'quote'),
        ),
        const Gap(Space.s3),
        Btn('Cancel', kind: BtnKind.secondary, block: true, onPressed: () => Navigator.pop(ctx)),
      ],
    ),
  );
  if (!context.mounted) return;
  if (pick == 'repost') {
    HapticFeedback.mediumImpact();
    final r = await toggleRepost(ref, p);
    if (context.mounted && r['ok'] == true) toast(context, r['reposted'] == true ? 'Reposted' : 'Repost removed', icon: PhosphorIcons.repeat());
  } else if (pick == 'quote') {
    context.push('/community/compose', extra: {'quote': p});
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.icon, required this.tone, required this.bg, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final Color tone;
  final Color bg;
  final String title;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Radii.lg),
    child: Padding(
      padding: const EdgeInsets.all(Space.s3),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tone, size: 22),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.ty.body.bold),
                Text(text, style: context.ty.sm.col(context.c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- menu, report

Future<String?> pickReportReason(BuildContext context) => showSheet<String>(
  context,
  builder: (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Why are you reporting this?', style: ctx.ty.h3),
      const Gap(Space.s3),
      ListCard(
        children: [
          for (final r in const [
            'Rude, bullying or hateful',
            'Sexual or not for students',
            'Politics, betting or sports gossip',
            'Sharing phone numbers or links',
            'Exam malpractice (expo)',
            'Scam or selling',
            'Wrong or harmful answer',
            'Something else',
          ])
            ListRow(title: r, onTap: () => Navigator.pop(ctx, r)),
        ],
      ),
    ],
  ),
);

/// Follow, report, block, delete, copy.
class PostMenu extends ConsumerWidget {
  const PostMenu({super.key, required this.post, this.onGone});
  final Json post;
  final VoidCallback? onGone;

  Future<bool> _rpc(BuildContext context, String fn, Map<String, dynamic> params, String done) async {
    try {
      await crpc(fn, params);
      if (context.mounted) toast(context, done, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      return true;
    } catch (_) {
      if (context.mounted) toast(context, offlineText);
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = post['mine'] == true;
    final page = post['page_id'] != null;
    final followKey = page ? '${post['page_id']}' : '${post['user_id']}';
    final following = ref.watch(followPatchesProvider.select((m) => m[followKey])) ?? post['following'] == true;
    final mod = ref.watch(communityMeProvider.select((v) => v.value?['mod'] == true));
    return SizedBox(
      width: 32,
      height: 28,
      child: PopupMenuButton<String>(
        tooltip: 'More',
        padding: EdgeInsets.zero,
        icon: Icon(PhosphorIcons.dotsThree(), color: context.c.textMuted, size: 20),
        onSelected: (v) async {
          switch (v) {
            case 'delete':
              final ok = await confirmDelete(context, 'Delete this post?');
              if (ok && context.mounted && await _rpc(context, 'community_post_delete', {'p_id': post['id']}, 'Post deleted')) {
                ref.read(postPatchesProvider.notifier).patch('${post['id']}', {'deleted': true});
                onGone?.call();
              }
            case 'copy':
              await Clipboard.setData(ClipboardData(text: '${post['body'] ?? ''}'));
              if (context.mounted) toast(context, 'Copied', icon: PhosphorIcons.copy());
            case 'report':
              final reason = await pickReportReason(context);
              if (reason != null && context.mounted) {
                await _rpc(context, 'community_report', {'p_kind': 'post', 'p_ref': '${post['id']}', 'p_reason': reason}, 'Thanks. We will look at it.');
              }
            case 'hide':
              if (await _rpc(context, 'community_hide', {'p_post': post['id']}, 'Got it. You will see fewer posts like this.')) {
                ref.read(postPatchesProvider.notifier).patch('${post['id']}', {'deleted': true});
                onGone?.call();
              }
            case 'mod':
              final reason = await pickRemoveReason(context);
              if (reason != null &&
                  context.mounted &&
                  await _rpc(context, 'community_mod_remove', {
                    'p_kind': 'post',
                    'p_id': '${post['id']}',
                    'p_reason': reason,
                  }, 'Removed. The student is told why.')) {
                ref.read(postPatchesProvider.notifier).patch('${post['id']}', {'deleted': true});
                onGone?.call();
              }
            case 'follow':
              final on = await toggleFollow(ref, followKey, following, page: page);
              if (context.mounted && on != null) toast(context, on ? 'Following @${post['handle']}' : 'Unfollowed @${post['handle']}');
            case 'block':
              final ok = await confirmBlock(context, '${post['handle']}');
              if (ok && context.mounted && await _rpc(context, 'community_block', {'p_user': post['user_id']}, 'Blocked. You will not see each other here.')) {
                ref.read(communityTickProvider.notifier).bump();
                onGone?.call();
              }
          }
        },
        itemBuilder: (_) => [
          if (!mine) PopupMenuItem(value: 'follow', child: Text(following ? 'Unfollow @${post['handle']}' : 'Follow @${post['handle']}')),
          const PopupMenuItem(value: 'copy', child: Text('Copy text')),
          if (!mine) const PopupMenuItem(value: 'hide', child: Text('Not interested in this')),
          if (mine) const PopupMenuItem(value: 'delete', child: Text('Delete post')),
          if (!mine && post['status'] == 'shown') const PopupMenuItem(value: 'report', child: Text('Report post')),
          if (!mine && !page) PopupMenuItem(value: 'block', child: Text('Block @${post['handle']}')),
          if (mod && !mine && post['status'] == 'shown') const PopupMenuItem(value: 'mod', child: Text('Remove post (moderator)')),
        ],
      ),
    );
  }
}

List<Widget> _yesNo(String yes) => [
  Builder(
    builder: (ctx) => Row(
      children: [
        Expanded(
          child: Btn('Cancel', kind: BtnKind.secondary, onPressed: () => Navigator.pop(ctx, false)),
        ),
        const Gap(Space.s3),
        Expanded(
          child: Btn(yes, kind: BtnKind.danger, onPressed: () => Navigator.pop(ctx, true)),
        ),
      ],
    ),
  ),
];

Future<bool> confirmDelete(BuildContext context, String title) async =>
    await showAppDialog<bool>(context, title: title, body: 'This cannot be undone.', actions: _yesNo('Delete')) == true;

Future<bool> confirmBlock(BuildContext context, String handle) async =>
    await showAppDialog<bool>(
      context,
      title: 'Block @$handle?',
      body: 'You will not see each other\'s posts, replies or profiles, and you will stop following each other.',
      actions: _yesNo('Block'),
    ) ==
    true;

// ---------------------------------------------------------------- the post cell

/// One post in a list (X style): avatar, name, @handle, time, subject, text, pictures, quote, AI answer, actions.
class PostCell extends ConsumerWidget {
  const PostCell({super.key, required this.post, this.onGone, this.animateIndex});
  final Json post;
  final VoidCallback? onGone;
  final int? animateIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patch = ref.watch(postPatchesProvider.select((m) => m['${post['id']}']));
    if (patch?['deleted'] == true) return const SizedBox.shrink();
    final p = {...post, ...?patch};
    final c = context.c;
    final status = '${p['status']}';
    final shown = status == 'shown';
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final subject = subjects.where((s) => s['id'] == p['subject_id']).firstOrNull?['name'];
    final imgs = [for (final x in (p['images'] as List? ?? const [])) '$x'];
    final by = p['reposted_by'] is Map ? asJson(p['reposted_by']) : null;
    void openUser() => p['page_id'] != null ? context.push('/community/u/${p['handle']}') : context.push('/community/user/${p['user_id']}');
    void open() => context.push('/community/post/${p['id']}');

    final cell = InkWell(
      onTap: open,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s3, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (by != null)
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 4),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.repeat(), size: 14, color: c.textMuted),
                    const Gap(6),
                    Flexible(
                      child: Text(
                        by['id'] == currentUserId() ? 'You reposted' : '${by['name']} reposted',
                        style: context.ty.cap.bold.col(c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CAvatar(name: '${p['name']}', photo: p['avatar_path'] as String?, onTap: openUser, brand: p['badge'] == 'official'),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The menu sits at the right edge (outside this column); the name gets the room first.
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: NameLine(
                          name: '${p['name']}',
                          nameStyle: context.ty.body.bold,
                          badge: p['badge'] != null ? CBadge('${p['badge']}') : null,
                          handle: '${p['handle'] ?? 'student'}',
                          time: agoText(p['created_at']),
                          metaStyle: context.ty.sm.col(c.textMuted),
                          onName: openUser,
                        ),
                      ),
                      if (subject != null) ...[const Gap(4), SubjectChip('$subject', id: p['subject_id'] as int?)],
                      if ('${p['body'] ?? ''}'.isNotEmpty) ...[const Gap(4), CText('${p['body']}', maxLines: 12)],
                      if (imgs.isNotEmpty) ...[const Gap(10), ImageGrid(keys: imgs, height: 170)],
                      if (p['quote'] is Map) ...[const Gap(10), QuoteCard(q: asJson(p['quote']))],
                      if (shown && '${p['ai_answer'] ?? ''}'.isNotEmpty) ...[const Gap(10), AiAnswerCard(text: '${p['ai_answer']}', onTap: open)],
                      if (status == 'pending') ...[const Gap(10), const CheckingNote()],
                      if (status == 'rejected') ...[
                        const Gap(10),
                        NotShownNote(
                          reason: p['reason'] as String?,
                          onDelete: () async {
                            if (!await confirmDelete(context, 'Delete this post?')) return;
                            try {
                              await crpc('community_post_delete', {'p_id': p['id']});
                              ref.read(postPatchesProvider.notifier).patch('${p['id']}', {'deleted': true});
                              onGone?.call();
                            } catch (_) {
                              if (context.mounted) toast(context, offlineText);
                            }
                          },
                        ),
                      ],
                      if (shown)
                        Padding(
                          padding: const EdgeInsets.only(left: 0, right: 0),
                          child: Transform.translate(
                            offset: const Offset(-8, 0),
                            child: PostActions(post: p),
                          ),
                        )
                      else
                        const Gap(Space.s3),
                    ],
                  ),
                ),
                PostMenu(post: p, onGone: onGone),
              ],
            ),
          ],
        ),
      ),
    );
    final i = animateIndex;
    if (i == null || i > 8 || context.reduceMotion) return cell;
    return cell.animate().fadeIn(delay: (35 * i).ms, duration: Motion.base).slideY(begin: .04, end: 0, curve: Motion.out);
  }
}

String? currentUserId() {
  try {
    return cdb.auth.currentUser?.id;
  } catch (_) {
    return null; // not signed in yet (or in tests)
  }
}

class SubjectChip extends StatelessWidget {
  const SubjectChip(this.name, {super.key, this.id});
  final String name;
  final int? id;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: id == null ? null : () => context.push('/community/subject/$id'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Text(name, style: context.ty.cap.bold.col(c.onSecondarySoft)),
      ),
    );
  }
}

/// Follow / Following / Follow back pill.
class FollowPill extends ConsumerWidget {
  const FollowPill({super.key, required this.user, required this.following, this.followsMe = false, this.handle, this.page = false});
  final String user;
  final bool following;
  final bool followsMe;
  final String? handle;
  final bool page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final on = ref.watch(followPatchesProvider.select((m) => m[user])) ?? following;
    final label = on ? 'Following' : (followsMe ? 'Follow back' : 'Follow');
    return Semantics(
      button: true,
      label: handle == null ? label : '$label @$handle',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          toggleFollow(ref, user, on, page: page);
        },
        child: AnimatedContainer(
          duration: context.reduceMotion ? Duration.zero : Motion.fast,
          constraints: const BoxConstraints(minHeight: 36, minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Colors.transparent : c.text,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? c.borderStrong : c.text),
          ),
          child: Text(label, style: context.ty.sm.bold.col(on ? c.text : c.surface)),
        ),
      ),
    );
  }
}

/// A person in a list: avatar, name, @handle (or why), bio, follow pill.
class PersonRow extends ConsumerWidget {
  const PersonRow({super.key, required this.p, this.why});
  final Json p;
  final String? why;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final me = p['id'] == currentUserId();
    final sub = why ?? (p['follows_me'] == true ? 'Follows you' : null);
    return InkWell(
      onTap: () => context.push('/community/user/${p['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10),
        child: Row(
          children: [
            CAvatar(name: '${p['name']}', photo: p['avatar_path'] as String?),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: FitText('${p['name']}', style: context.ty.body.bold)),
                      if (p['badge'] != null) ...[const Gap(4), CBadge('${p['badge']}')],
                    ],
                  ),
                  Text('@${p['handle']}${sub != null ? ' · $sub' : ''}', style: context.ty.sm.col(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ('${p['bio'] ?? ''}'.isNotEmpty) ...[
                    const Gap(2),
                    Text('${p['bio']}', style: context.ty.sm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (!me) ...[
              const Gap(Space.s2),
              FollowPill(user: '${p['id']}', following: p['following'] == true, followsMe: p['follows_me'] == true, handle: '${p['handle']}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading rows shaped like posts.
class PostSkeletons extends StatelessWidget {
  const PostSkeletons({super.key, this.count = 4});
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(6)),
    );
    final rows = Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.surfaceSunken, shape: BoxShape.circle),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(150, 12),
                      const Gap(10),
                      bar(double.infinity, 10),
                      const Gap(8),
                      bar(220, 10),
                      if (i.isOdd) ...[const Gap(10), bar(double.infinity, 110)],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (context.reduceMotion) return rows;
    return rows.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1400.ms, color: c.surface.withValues(alpha: .5));
  }
}

/// The SolutionTee mark next to a name: SolutionTee pages, staff and Community moderators (they work for SolutionTee);
/// a gold seal for SolutionTee AI.
class CBadge extends StatelessWidget {
  const CBadge(this.kind, {super.key, this.size = 16});
  final String kind;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (kind == 'ai') return AiSeal(size: size);
    final label = switch (kind) {
      'official' => 'Official SolutionTee page',
      'page' => 'SolutionTee page',
      'mod' => 'SolutionTee Community moderator',
      _ => 'SolutionTee team',
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * .3),
            border: Border.all(color: kind == 'official' ? Palette.gold400 : Palette.blue600, width: 1.2),
          ),
          child: const Mark(onDark: false),
        ),
      ),
    );
  }
}

/// Why a moderator takes a post or reply down (the student sees it).
Future<String?> pickRemoveReason(BuildContext context) => showSheet<String>(
  context,
  builder: (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Why remove it?', style: ctx.ty.h3),
      const Gap(4),
      Text('The student is told why and gets a strike. Repeated strikes pause their posting.', style: ctx.ty.sm.col(ctx.c.textMuted)),
      const Gap(Space.s3),
      ListCard(
        children: [
          for (final r in const [
            'Rude, bullying or hateful',
            'Sexual or not for students',
            'Politics, betting or sports gossip',
            'Phone numbers, links or contacts',
            'Exam malpractice (expo)',
            'Scam, selling or spam',
            'Wrong or harmful information',
          ])
            ListRow(title: r, onTap: () => Navigator.pop(ctx, r)),
        ],
      ),
    ],
  ),
);

// ---------------------------------------------------------------- @ suggestions

/// While someone types "@s…" in a post or reply, this lists matching pages and students (SolutionTee first). Tap one:
/// it finishes the @handle in the text (owner, 13 Nov 2026).
class MentionSuggestions extends StatefulWidget {
  const MentionSuggestions({super.key, required this.controller, this.focus, this.maxRows = 4});
  final TextEditingController controller;
  final FocusNode? focus;
  final int maxRows;
  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  static final _cache = <String, List<Json>>{};
  String? _q; // the letters after "@" at the cursor, or null
  List<Json> _rows = const [];
  int _ask = 0;

  static final _at = RegExp(r'(^|[\s(])@([a-zA-Z0-9_.]{0,20})$');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focus?.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focus?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final v = widget.controller.value;
    final cur = v.selection.baseOffset;
    String? q;
    if (cur >= 0 && cur <= v.text.length && (widget.focus?.hasFocus ?? true)) {
      q = _at.firstMatch(v.text.substring(0, cur))?.group(2)?.toLowerCase();
    }
    if (q == _q) return;
    setState(() => _q = q);
    if (q == null) return;
    final hit = _cache[q];
    if (hit != null) return setState(() => _rows = hit);
    final ask = ++_ask;
    Future<void>.delayed(const Duration(milliseconds: 180), () async {
      if (!mounted || ask != _ask) return;
      try {
        final r = asList(await crpc('community_mention_suggest', {'p_q': q}));
        _cache[q!] = r;
        if (mounted && ask == _ask) setState(() => _rows = r);
      } catch (_) {}
    });
  }

  void _pick(Json r) {
    final v = widget.controller.value;
    final cur = v.selection.baseOffset;
    final before = v.text.substring(0, cur);
    final m = _at.firstMatch(before);
    if (m == null) return;
    final start = m.start + m.group(1)!.length;
    final insert = '@${r['handle']} ';
    final text = before.substring(0, start) + insert + v.text.substring(cur);
    widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + insert.length));
    setState(() {
      _q = null;
      _rows = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final show = _q != null && _rows.isNotEmpty;
    return AnimatedSize(
      duration: Motion.fast,
      curve: Motion.out,
      alignment: Alignment.bottomCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: 54.0 * widget.maxRows + 8),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: c.borderStrong),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final r in _rows)
                    InkWell(
                      onTap: () => _pick(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            CAvatar(name: '${r['name']}', photo: r['avatar_path'] as String?, size: 36, brand: r['badge'] == 'official'),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(child: FitText('${r['name']}', style: context.ty.sm.bold)),
                                      if (r['badge'] != null) ...[const Gap(4), CBadge('${r['badge']}', size: 14)],
                                    ],
                                  ),
                                  Text('@${r['handle']}', style: context.ty.cap.col(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: Motion.fast),
                ],
              ),
            ),
    );
  }
}
