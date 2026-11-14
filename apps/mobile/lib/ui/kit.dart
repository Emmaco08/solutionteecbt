/// SolutionTee component kit: Flutter versions of the approved Phase 1 prototype components
/// (prototype/css/base.css + app.css). Names follow the prototype classes so screens can be ported 1:1.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/phosphor.g.dart';
import '../core/platform.dart';

// ---------------------------------------------------------------- typography (.t-*)
TextStyle _t(({double size, double line, int weight, double tracking}) s, Color c) => TextStyle(
  fontFamily: kFont,
  fontSize: s.size,
  height: s.line / s.size,
  fontWeight: s.weight >= 700 ? FontWeight.w700 : FontWeight.w500,
  letterSpacing: s.tracking,
  color: c,
);

/// `context.ty.h1` etc. Same scale as the prototype's `.t-display`, `.t-h1` … `.t-over`.
class Ty {
  Ty(this.c);
  final AppColors c;
  TextStyle get display => _t(TypeScale.display, c.text);
  TextStyle get h1 => _t(TypeScale.h1, c.text);
  TextStyle get h2 => _t(TypeScale.h2, c.text);
  TextStyle get h3 => _t(TypeScale.h3, c.text);
  TextStyle get lg => _t(TypeScale.bodyLg, c.text);
  TextStyle get body => _t(TypeScale.body, c.text);
  TextStyle get sm => _t(TypeScale.bodySm, c.text);
  TextStyle get cap => _t(TypeScale.caption, c.text);
  TextStyle get over => _t(TypeScale.overline, c.textSubtle);
  TextStyle get label => _t(TypeScale.label, c.text);
  TextStyle get timer => _t(TypeScale.timer, c.text).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

extension KitX on BuildContext {
  Ty get ty => Ty(c);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  List<BoxShadow> shadow(int level) => switch ((isDark, level)) {
    (false, 1) => Shadows.light1,
    (false, 2) => Shadows.light2,
    (false, 3) => Shadows.light3,
    (false, 4) => Shadows.light4,
    (true, 1) => Shadows.dark1,
    (true, 2) => Shadows.dark2,
    (true, 3) => Shadows.dark3,
    (true, 4) => Shadows.dark4,
    _ => const [],
  };
}

extension TyX on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get tnum => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  TextStyle col(Color c) => copyWith(color: c);
}

const kBold = FontWeight.w700;

/// Vertical / horizontal gaps on the 8-pt scale (`.g2`, `.mt3`, …).
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

// ---------------------------------------------------------------- press scale (.btn:active)
/// Scales its child to [scale] while pressed (prototype `--press-scale`). Off under reduce motion.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = Motion.pressScale, this.borderRadius});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return AnimatedScale(
      scale: _down && !context.reduceMotion ? widget.scale : 1,
      duration: Motion.fast,
      curve: Motion.out,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: on ? (v) => setState(() => _down = v) : null,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- buttons (.btn)
enum BtnKind { primary, secondary, accent, outline, tonal, ghost, danger, google }

class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.sm = false,
    this.block = false,
    this.loading = false,
    this.icon,
    this.trailing,
    this.leading,
    this.lead,
  });
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool sm, block, loading;

  /// Icon after the label (e.g. arrow-right), as in the prototype.
  final IconData? icon;

  /// Icon before the label.
  final IconData? leading;
  final Widget? trailing;

  /// A picture before the label (e.g. Google's G), when an icon is not enough.
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, ring) = switch (kind) {
      BtnKind.primary => (c.primary, c.onPrimary, null),
      BtnKind.secondary => (c.secondary, c.onSecondary, null),
      BtnKind.accent => (c.accent, c.onAccent, null),
      BtnKind.outline || BtnKind.google => (c.surface, c.text, c.borderStrong),
      BtnKind.tonal => (c.primarySoft, c.onPrimarySoft, null),
      BtnKind.ghost => (Colors.transparent, c.link, null),
      BtnKind.danger => (c.error, c.textInverse, null),
    };
    final shadow = kind == BtnKind.primary || kind == BtnKind.accent ? context.shadow(1) : const <BoxShadow>[];
    final radius = BorderRadius.circular(sm ? Radii.sm : Radii.md);
    final disabled = onPressed == null && !loading;
    final style = (sm ? context.ty.sm : context.ty.label).bold.col(fg);
    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[Icon(leading, size: 20, color: fg), const Gap(Space.s2)] else if (lead != null) ...[lead!, const Gap(Space.s3)],
        Flexible(
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (icon != null) ...[const Gap(Space.s2), Icon(icon, size: 20, color: fg)],
        ?trailing,
        if (loading) ...[const Gap(Space.s2), SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))],
      ],
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      child: AnimatedOpacity(
        opacity: disabled ? .45 : 1,
        duration: Motion.fast,
        child: Pressable(
          onTap: loading ? null : onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              boxShadow: shadow,
              border: ring == null ? null : Border.all(color: ring, width: 1.5),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: sm ? 40 : Sizes.buttonHeight, minWidth: block ? double.infinity : 0),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: kind == BtnKind.ghost ? Space.s3 : (sm ? Space.s4 : Space.s5)),
                child: Center(widthFactor: 1, heightFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 48 dp round icon button (`.icon-btn`).
class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.label, this.onPressed, this.color, this.size = Sizes.icon, this.glass = false, this.child});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool glass;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Pressable(
      onTap: onPressed,
      scale: .92,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        width: Sizes.tapMin,
        height: Sizes.tapMin,
        decoration: glass ? const BoxDecoration(color: Color.fromRGBO(6, 19, 43, .45), shape: BoxShape.circle) : null,
        alignment: Alignment.center,
        child: child ?? Icon(icon, size: size, color: glass ? Colors.white : (color ?? context.c.text), semanticLabel: label),
      ),
    ),
  );
}

// ---------------------------------------------------------------- app bar + footer (.appbar, .footer-cta)
/// Prototype app bar: 56 high, back icon button, title (+ small subtitle), actions. No Material elevation.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key, this.title, this.subtitle, this.onBack, this.actions = const [], this.center, this.lined = false, this.showBack = true});
  final String? title, subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? center;
  final bool lined, showBack;
  @override
  Size get preferredSize => const Size.fromHeight(Sizes.appBar);
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      height: Sizes.appBar + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, left: Space.s2, right: Space.s2),
      decoration: BoxDecoration(
        color: context.c.bg,
        border: lined ? Border(bottom: BorderSide(color: context.c.border)) : null,
      ),
      child: Row(
        children: [
          if (showBack && (onBack != null || canPop))
            IconBtn(PhosphorIcons.arrowLeft(), label: 'Back', onPressed: onBack ?? () => Navigator.of(context).maybePop()),
          if (center != null)
            Expanded(child: center!)
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: Space.s1),
                child: title == null
                    ? const SizedBox()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title!, style: context.ty.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (subtitle != null) Text(subtitle!, style: context.ty.cap.col(context.c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
              ),
            ),
          ...actions,
        ],
      ),
    );
  }
}

/// Bottom action area (`.footer-cta`), sits above the system inset.
class FooterCta extends StatelessWidget {
  const FooterCta({super.key, required this.child, this.clean = false, this.transparent = false});
  final Widget child;
  final bool clean, transparent;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s5 + MediaQuery.paddingOf(context).bottom),
    decoration: BoxDecoration(
      color: transparent ? Colors.transparent : context.c.bg,
      border: clean ? null : Border(top: BorderSide(color: context.c.border)),
    ),
    child: child,
  );
}

// ---------------------------------------------------------------- surfaces (.card, .list-item)
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.pad = true, this.onTap, this.color, this.padding, this.clip = false});
  final Widget child;
  final bool pad, clip;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Radii.lg);
    final body = Padding(padding: padding ?? (pad ? const EdgeInsets.all(Space.s4) : EdgeInsets.zero), child: child);
    final box = Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color ?? context.c.surface,
        borderRadius: r,
        border: Border.all(color: context.c.border),
        boxShadow: context.shadow(1),
      ),
      child: onTap == null ? body : Pressable(onTap: onTap, scale: .985, borderRadius: r, child: body),
    );
    return box;
  }
}

/// Coloured icon tile (`.lead`, `.ic.navy|blue|gold|green|red`).
enum Tone { navy, blue, gold, green, red, neutral }

(Color, Color) toneColors(BuildContext context, Tone t) {
  final c = context.c;
  return switch (t) {
    Tone.navy => (c.primarySoft, c.onPrimarySoft),
    Tone.blue => (c.secondarySoft, c.onSecondarySoft),
    Tone.gold => (c.accentSoft, c.onAccentSoft),
    Tone.green => (c.successSoft, c.onSuccessSoft),
    Tone.red => (c.errorSoft, c.onErrorSoft),
    Tone.neutral => (c.surfaceSunken, c.textMuted),
  };
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.navy, this.size = 40, this.radius = Radii.sm, this.iconSize});
  final IconData icon;
  final Tone tone;
  final double size, radius;
  final double? iconSize;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size / 2, color: fg),
    );
  }
}

/// A row in a `.card.list`: 40 lead tile, title + caption, trailing caret.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.icon,
    this.lead,
    this.tone = Tone.navy,
    required this.title,
    this.caption,
    this.trailing,
    this.onTap,
    this.caret = true,
    this.danger = false,
  });
  final IconData? icon;
  final Widget? lead;
  final Tone tone;
  final String title;
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool caret, danger;
  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
        child: Row(
          children: [
            if (lead != null) lead! else if (icon != null) IconTile(icon!, tone: danger ? Tone.red : tone),
            if (lead != null || icon != null) const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.ty.sm.bold.col(danger ? context.c.error : context.c.text)),
                  if (caption != null) Text(caption!, style: context.ty.cap.col(context.c.textMuted)),
                ],
              ),
            ),
            ?trailing,
            if (caret && onTap != null && trailing == null) Icon(PhosphorIcons.caretRight(), size: 18, color: context.c.textSubtle),
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// `.card.list`: rows separated by 1 px borders.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    pad: false,
    clip: true,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, thickness: 1, color: context.c.border), children[i]],
      ],
    ),
  );
}

/// Section title (`.sect-title`) with an optional ghost action.
class SectTitle extends StatelessWidget {
  const SectTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(title, style: context.ty.h3)),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(widthFactor: 1, child: Text(action!, style: context.ty.sm.bold.col(context.c.link))),
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- badges, chips, pills
enum BadgeKind { gold, soft, success, warning, error, neutral, sample }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.kind = BadgeKind.soft, this.icon});
  final String text;
  final BadgeKind kind;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (kind) {
      BadgeKind.gold => (c.accent, c.onAccent),
      BadgeKind.soft => (c.secondarySoft, c.onSecondarySoft),
      BadgeKind.success => (c.successSoft, c.onSuccessSoft),
      BadgeKind.warning || BadgeKind.sample => (c.warningSoft, c.onWarningSoft),
      BadgeKind.error => (c.errorSoft, c.onErrorSoft),
      BadgeKind.neutral => (c.surfaceSunken, c.textMuted),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: context.ty.cap.bold.col(fg).copyWith(letterSpacing: kind == BadgeKind.sample ? .6 : null)),
        ],
      ),
    );
  }
}

/// Filter chip (`.chip`, `.chip.on`).
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, required this.on, this.onTap, this.icon, this.dot = false});
  final String label;
  final bool on;

  /// A small unread dot after the label (prototype `.chip .unread-dot`).
  final bool dot;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      selected: on,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: .96,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 6),
          decoration: BoxDecoration(
            color: on ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: on ? null : Border.all(color: c.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: on ? c.onPrimary : c.textMuted), const SizedBox(width: 6)],
              // Long labels (topic names) wrap to two lines and never run off the screen (owner, 2026-11-08).
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width - 96).clamp(120, 900)),
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, softWrap: true, style: context.ty.sm.bold.col(on ? c.onPrimary : c.textMuted)),
              ),
              if (dot) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: on ? c.onPrimary : c.secondary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- forms (.field, .input)
class Field extends StatefulWidget {
  const Field({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.password = false,
    this.help,
    this.error,
    this.keyboard,
    this.autofill,
    this.action,
    this.onSubmitted,
    this.onChanged,
    this.caps = TextCapitalization.none,
    this.maxLength,
    this.formatters,
    this.enabled = true,
    this.mono = false,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController? controller;
  final String? hint, help, error;
  final IconData? icon;
  final bool password, enabled, mono, autofocus;
  final TextInputType? keyboard;
  final Iterable<String>? autofill;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted, onChanged;
  final TextCapitalization caps;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  bool _show = false;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final err = widget.error != null;
    final ring = err ? c.error : (_focus.hasFocus ? c.secondary : c.borderStrong);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: context.ty.sm.bold),
        const Gap(Space.s2),
        AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: Sizes.inputHeight),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: ring, width: err || _focus.hasFocus ? 2 : 1.5),
          ),
          child: Row(
            children: [
              if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.s4),
                  child: Icon(widget.icon, size: 20, color: c.textSubtle),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  obscureText: widget.password && !_show,
                  keyboardType: widget.keyboard,
                  autofillHints: widget.autofill,
                  textInputAction: widget.action,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  textCapitalization: widget.caps,
                  maxLength: widget.maxLength,
                  inputFormatters: widget.formatters,
                  style: context.ty.body.copyWith(fontSize: 16, letterSpacing: widget.mono ? 1.5 : null),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: context.ty.body.copyWith(fontSize: 16).col(c.textSubtle),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    isCollapsed: true,
                    contentPadding: EdgeInsets.fromLTRB(widget.icon != null ? Space.s3 : Space.s4, 15, Space.s4, 15),
                  ),
                ),
              ),
              if (widget.password)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconBtn(
                    _show ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                    label: _show ? 'Hide password' : 'Show password',
                    color: c.textSubtle,
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
            ],
          ),
        ),
        if (err) ...[
          const Gap(Space.s2),
          ErrText(widget.error!),
        ] else if (widget.help != null) ...[
          const Gap(Space.s2),
          Text(widget.help!, style: context.ty.cap.col(c.textMuted)),
        ],
      ],
    );
  }
}

/// `.err`: red bold caption with a warning icon.
class ErrText extends StatelessWidget {
  const ErrText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), size: 14, color: context.c.error),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: context.ty.cap.bold.col(context.c.error))),
      ],
    ),
  );
}

/// `.check` with a 22 px checkbox in the secondary colour; `.consent.has-error` turns the block red.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.value, required this.onChanged, required this.child, this.error});
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bad = error != null;
    return AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: bad ? c.errorSoft : Colors.transparent, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: c.secondary,
                    side: BorderSide(color: bad ? c.error : c.borderStrong, width: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: DefaultTextStyle(style: context.ty.sm.col(bad ? c.onErrorSoft : c.textMuted), child: child),
                ),
              ],
            ),
          ),
          if (bad) ...[const Gap(Space.s2), ErrText(error!)],
        ],
      ),
    );
  }
}

/// `.or` divider: line · OR · line.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: context.c.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s3),
        child: Text('OR', style: context.ty.cap.bold.col(context.c.textSubtle)),
      ),
      Expanded(child: Divider(color: context.c.border)),
    ],
  );
}

/// `.seg` segmented control.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.value, required this.items, required this.onChanged});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  selected: v == value,
                  button: true,
                  child: InkWell(
                    onTap: () => onChanged(v),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == value ? c.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: v == value ? context.shadow(1) : null,
                      ),
                      child: Text(label, style: context.ty.sm.bold.col(v == value ? c.text : c.textMuted)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.switch`: 52×32, secondary when on.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: value ? c.secondary : c.borderStrong, borderRadius: BorderRadius.circular(99)),
          child: AnimatedAlign(
            duration: Motion.base,
            curve: Motion.emphasized,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: context.shadow(1)),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- progress (.bar, .steps)
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color, this.height = 8, this.track});
  final double value;
  final Color? color, track;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: Container(
      height: height,
      color: track ?? context.c.surfaceSunken,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: context.reduceMotion ? Duration.zero : Motion.slow,
        curve: Motion.out,
        builder: (_, v, _) => FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(color: color ?? context.c.secondary, borderRadius: BorderRadius.circular(99)),
          ),
        ),
      ),
    ),
  );
}

/// `.steps`: N segments, filled up to [step] (1-based).
class StepsBar extends StatelessWidget {
  const StepsBar({super.key, required this.step, required this.total});
  final int step, total;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= total; i++) ...[if (i > 1) const SizedBox(width: 6), Expanded(child: ProgressBar(i <= step ? 1 : 0, height: 5))],
    ],
  );
}

/// Onboarding dots (`.ob-dots`).
class Dots extends StatelessWidget {
  const Dots({super.key, required this.count, required this.index});
  final int count, index;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        AnimatedContainer(
          duration: Motion.base,
          curve: Motion.out,
          width: i == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(color: i == index ? context.c.primary : context.c.borderStrong, borderRadius: BorderRadius.circular(9)),
        ),
      ],
    ],
  );
}

// ---------------------------------------------------------------- feedback (.banner, .state)
enum BannerKind { info, warn, err, ok }

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.child, this.kind = BannerKind.info, this.icon});
  final Widget child;
  final BannerKind kind;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, ic) = switch (kind) {
      BannerKind.info => (c.secondarySoft, c.onSecondarySoft, PhosphorIcons.info(PhosphorIconsStyle.fill)),
      BannerKind.warn => (c.warningSoft, c.onWarningSoft, PhosphorIcons.warning(PhosphorIconsStyle.fill)),
      BannerKind.err => (c.errorSoft, c.onErrorSoft, PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)),
      BannerKind.ok => (c.successSoft, c.onSuccessSoft, PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          Icon(icon ?? ic, size: 20, color: fg),
          const Gap(Space.s3),
          Expanded(
            child: DefaultTextStyle(style: context.ty.sm.col(fg), child: child),
          ),
        ],
      ),
    );
  }
}

/// `.state` block: 112 art tile (radius 32), title, text, action.
class StateBlock extends StatelessWidget {
  const StateBlock({super.key, required this.icon, required this.title, this.text, this.action, this.tone = Tone.navy});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context, tone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s6, Space.s8, Space.s6, Space.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(32)),
            child: Icon(icon, size: 52, color: fg),
          ),
          const Gap(Space.s2 + Space.s3),
          Text(title, style: context.ty.h2, textAlign: TextAlign.center),
          if (text != null) ...[
            const Gap(Space.s3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(text!, style: context.ty.body.col(context.c.textMuted), textAlign: TextAlign.center),
            ),
          ],
          if (action != null) ...[const Gap(Space.s3), action!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- art (.art-disc, .mini, .disclaimer)
class ArtDisc extends StatelessWidget {
  const ArtDisc({super.key, this.size = 260, this.tone = Tone.navy, this.breathe = true});
  final double size;
  final Tone tone;
  final bool breathe;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (tone) {
      Tone.gold => c.accentSoft,
      Tone.blue => c.secondarySoft,
      _ => c.primarySoft,
    };
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!breathe || context.reduceMotion) return disc;
    return _Loop(
      period: const Duration(seconds: 6),
      builder: (t) => Transform.scale(scale: 1 + .05 * _wave(t), child: disc),
    );
  }
}

/// Floating "mini" card used in onboarding art (`.mini`).
class Mini extends StatelessWidget {
  const Mini({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.width});
  final Widget child;
  final EdgeInsets padding;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: padding,
    decoration: BoxDecoration(
      color: context.c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.c.border),
      boxShadow: context.shadow(3),
    ),
    child: child,
  );
}

/// Gentle up/down float (`.fx-float`), optional fixed rotation. Static under reduce motion.
class Float extends StatelessWidget {
  const Float({super.key, required this.child, this.rotate = 0, this.delay = 0});
  final Widget child;
  final double rotate; // degrees
  final double delay; // seconds (negative = start part-way)
  @override
  Widget build(BuildContext context) {
    final rotated = Transform.rotate(angle: rotate * 3.14159 / 180, child: child);
    if (context.reduceMotion) return rotated;
    return _Loop(
      period: const Duration(milliseconds: 4500),
      offset: delay / 4.5,
      builder: (t) => Transform.translate(offset: Offset(0, -8 * _wave(t)), child: rotated),
    );
  }
}

/// 0 → 1 → 0 over one period (ease-in-out).
double _wave(double t) => (1 - (t * 2 - 1).abs());

class _Loop extends StatefulWidget {
  const _Loop({required this.period, required this.builder, this.offset = 0});
  final Duration period;
  final double offset;
  final Widget Function(double t) builder;
  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (_, _) => widget.builder(Curves.easeInOut.transform(((_c.value + widget.offset) % 1 + 1) % 1)));
}

class Disclaimer extends StatelessWidget {
  const Disclaimer(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: context.ty.cap.copyWith(fontSize: 11, height: 15 / 11, letterSpacing: 0).col(context.c.textSubtle),
  );
}

// ---------------------------------------------------------------- brand
/// SolutionTee mark: mark-light on light surfaces, mark-dark on dark (prototype `ST.mark`). Real files only.
class Mark extends StatelessWidget {
  const Mark({super.key, this.height = 28, this.onDark});
  final double height;
  final bool? onDark;
  @override
  Widget build(BuildContext context) => Image.asset(
    (onDark ?? context.isDark) ? 'assets/brand/solutiontee-mark-dark.png' : 'assets/brand/solutiontee-mark-light.png',
    height: height,
    semanticLabel: 'SolutionTee',
  );
}

/// The app icon (brand/favicon.svg, unchanged): navy rounded square with the mark.
class AppIconArt extends StatelessWidget {
  const AppIconArt({super.key, this.size = 108});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * 26 / 108), boxShadow: context.shadow(3)),
    child: SvgPicture.asset('assets/brand/solutiontee-app-icon.svg', width: size, height: size, semanticsLabel: 'SolutionTee app icon'),
  );
}

/// Avatar (`.avatar`): initials on gold, sizes 44 / lg 72 / xl.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 44, this.photo});
  final String name;
  final double size;

  /// A profile photo drawn over the initials when it has loaded (e.g. an R2Image), D-063.
  final Widget? photo;
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.c.accent, shape: BoxShape.circle),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Text(initials(name), style: context.ty.label.bold.copyWith(fontSize: size * .34, height: 1).col(context.c.onAccent)),
        ),
        ?photo,
      ],
    ),
  );
}

// ---------------------------------------------------------------- bottom sheet (.sheet)
/// Opens a prototype-style sheet: 28 radius, grab handle, body padding 20.
/// Bottom sheet above the bottom tabs (root navigator), inside the safe area, with a handle and a close (X) button.
/// The phone's back button closes it too.
Future<T?> showSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder, bool scroll = false, bool closeButton = true}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      // Desktop (D-166): a sheet the width of a phone, not of the whole page.
      constraints: isDesktop ? const BoxConstraints(maxWidth: 640) : null,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: closeButton ? 48 : 17,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.fromLTRB(0, 10, 0, 2),
                    decoration: BoxDecoration(color: ctx.c.borderStrong, borderRadius: BorderRadius.circular(9)),
                  ),
                  if (closeButton)
                    Positioned(
                      right: 8,
                      top: 4,
                      child: IconButton(
                        key: const ValueKey('sheet-close'),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        icon: Icon(PhosphorIcons.x(), size: 20, color: ctx.c.textMuted),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(Space.s5, closeButton ? 0 : Space.s3, Space.s5, Space.s6 + MediaQuery.paddingOf(ctx).bottom),
                child: builder(ctx),
              ),
            ),
          ],
        ),
      ),
    );

/// Prototype dialog: 24 radius, 24/20 padding, title + body + actions stacked.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? body,
  Widget? content,
  IconData? icon,
  Tone tone = Tone.navy,
  required List<Widget> actions,
}) => showDialog<T>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: ctx.c.surface,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s6, Space.s5, Space.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconTile(icon, tone: tone, size: 56, radius: 16),
            ),
            const Gap(Space.s4),
          ],
          Text(title, style: ctx.ty.h2),
          if (body != null) ...[const Gap(Space.s2), Text(body, style: ctx.ty.body.col(ctx.c.textMuted))],
          if (content != null) ...[const Gap(Space.s3), content],
          const Gap(Space.s5),
          for (var i = 0; i < actions.length; i++) ...[if (i > 0) const Gap(Space.s2), actions[i]],
        ],
      ),
    ),
  ),
);

/// Prototype toast: navy-950 pill above the bottom nav, with an icon.
/// [above] lifts it over a bottom bar (CBT bottom bar, footer buttons) so it never covers controls.
/// Desktop (D-166): Enter sends a chat message, Shift+Enter starts a new line. Phones keep their keyboard's own key.
class EnterToSend extends StatelessWidget {
  const EnterToSend({super.key, required this.onSend, required this.child});
  final VoidCallback? onSend;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final send = onSend;
    if (!isDesktop || send == null) return child;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): send, const SingleActivator(LogicalKeyboardKey.numpadEnter): send},
      child: child,
    );
  }
}

/// Desktop (D-166): toasts stay about 520 px wide in the middle instead of spanning the page.
double _toastSide(BuildContext context) => isDesktop ? ((MediaQuery.sizeOf(context).width - 520) / 2).clamp(16.0, 4000.0) : 16;

void toast(BuildContext context, String text, {IconData? icon, double above = 0}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.navy950,
      margin: EdgeInsets.fromLTRB(_toastSide(context), 0, _toastSide(context), 16 + above),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      content: Row(
        children: [
          Icon(icon ?? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 20, color: Palette.gold400),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.ty.sm.bold.col(const Color(0xFFF4F7FC)))),
        ],
      ),
    ),
  );
}
