import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/platform.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// Calculator sheet (prototype CBT calculator): the sum on top, the answer below (shrinks to fit),
/// thousands separators and left-to-right chaining like a simple calculator.
/// On Windows (owner, 16 Nov 2026, D-178) it is a small floating panel beside the question instead of a tall sheet over
/// it, like the calculator window in the real CBT centre: drag it by its top bar, type with the keyboard, close with X
/// or Esc, and keep answering while it is open.
void showCalculator(BuildContext context) {
  if (isDesktop) {
    _DesktopCalc.toggle(context);
    return;
  }
  showSheet<void>(context, builder: (_) => const _Calculator());
}

/// Closes the floating calculator (the exam is leaving).
void closeCalculator() => _DesktopCalc.close();

abstract final class _DesktopCalc {
  static OverlayEntry? _entry;
  static Offset _pos = const Offset(-1, -1);

  static void close() {
    final e = _entry;
    _entry = null;
    if (e == null) return;
    void remove() {
      try {
        if (e.mounted) e.remove();
        e.dispose();
      } catch (_) {}
    }

    // Closing while the exam screen is being taken down: remove after this frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      remove();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => remove());
    }
  }

  static void toggle(BuildContext context) {
    if (_entry != null) return close();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        const w = 320.0, h = 470.0;
        if (_pos.dx < 0) _pos = Offset(size.width - w - 340, size.height - h - 96);
        final pos = Offset(_pos.dx.clamp(8, size.width - w - 8), _pos.dy.clamp(8, size.height - h - 8));
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          width: w,
          child: _FloatingCalc(
            onMove: (d) {
              _pos = pos + d;
              _entry?.markNeedsBuild();
            },
            onClose: close,
          ),
        );
      },
    );
    overlay.insert(_entry!);
  }
}

class _FloatingCalc extends StatelessWidget {
  const _FloatingCalc({required this.onMove, required this.onClose});
  final ValueChanged<Offset> onMove;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanUpdate: (d) => onMove(d.delta),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.only(left: Space.s4, right: Space.s1),
                  color: c.surfaceSunken,
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.calculator(PhosphorIconsStyle.fill), size: 18, color: c.secondary),
                      const Gap(Space.s2),
                      Expanded(child: Text('Calculator', style: context.ty.label.bold)),
                      Text('Drag to move', style: context.ty.cap.col(c.textSubtle)),
                      IconButton(tooltip: 'Close (Esc)', visualDensity: VisualDensity.compact, onPressed: onClose, icon: Icon(PhosphorIcons.x(), size: 18)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s3, Space.s3, Space.s3, Space.s3),
              child: _Calculator(compact: true, onClose: onClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pure calculator logic, kept apart from the UI so it can be unit tested. Mirrors the prototype's `press()`.
class CalcEngine {
  final List<String> _expr = [];
  String _cur = '0';
  bool _done = false;
  String _err = '';

  static const ops = '÷×−+';

  /// The answer line (formatted), or the error text.
  String get display => _err.isNotEmpty ? _err : fmt(_cur);
  bool get isError => _err.isNotEmpty;

  /// The sum line, e.g. "12 + 30 =".
  String get expression => _expr.map((t) => ops.contains(t) ? ' $t ' : fmt(t)).join() + (_done ? ' =' : '');

  void press(String k) {
    if (k == 'C') {
      _reset();
    } else if (_err.isNotEmpty) {
      _reset();
      if (RegExp(r'[\d.]').hasMatch(k)) press(k);
      return;
    } else if (RegExp(r'^\d$').hasMatch(k) || k == '.') {
      if (_done) {
        _expr.clear();
        _cur = '0';
        _done = false;
      }
      if (k == '.') {
        if (!_cur.contains('.')) _cur = '${_cur.isEmpty ? '0' : _cur}.';
      } else if (_cur.replaceAll(RegExp(r'[-.]'), '').length < 15) {
        _cur = (_cur == '0' ? '' : (_cur == '-0' ? '-' : _cur)) + k;
      }
    } else if (ops.contains(k)) {
      if (_done) {
        _expr
          ..clear()
          ..add(_cur)
          ..add(k);
        _done = false;
        _cur = '';
      } else if (_cur.isEmpty && _expr.isNotEmpty) {
        _expr[_expr.length - 1] = k; // change operator
      } else {
        _expr
          ..add(_trimDot(_cur))
          ..add(k);
        _cur = '';
      }
    } else if (k == '=') {
      if (_done) return;
      final toks = _cur.isEmpty ? _expr.sublist(0, _expr.isEmpty ? 0 : _expr.length - 1) : [..._expr, _trimDot(_cur)];
      if (toks.length < 3) {
        if (_cur.isEmpty) _cur = toks.isEmpty ? '0' : toks.first;
        _expr.clear();
        return;
      }
      final r = _calc(toks);
      _expr
        ..clear()
        ..addAll(toks);
      _done = true;
      if (r.$2 != null) {
        _err = r.$2!;
      } else {
        _cur = r.$1!;
      }
    } else if (k == '⌫') {
      if (_done) {
        _expr.clear();
        _done = false;
      } else if (_cur.length > 1 && _cur != '-0') {
        _cur = _cur.substring(0, _cur.length - 1);
        if (_cur == '-') _cur = '0';
      } else if (_cur.isEmpty && _expr.isNotEmpty) {
        _expr.removeLast();
        _cur = _expr.isNotEmpty ? _expr.removeLast() : '0';
      } else {
        _cur = '0';
      }
    } else if (k == '±') {
      if (_cur.isNotEmpty && _cur != '0') _cur = _cur.startsWith('-') ? _cur.substring(1) : '-$_cur';
    } else if (k == '%') {
      if (_cur.isNotEmpty) _cur = _num(double.parse(_cur) / 100);
    }
  }

  void _reset() {
    _expr.clear();
    _cur = '0';
    _done = false;
    _err = '';
  }

  static String _trimDot(String s) => s.endsWith('.') ? s.substring(0, s.length - 1) : s;

  /// Left to right, like a basic calculator (2 + 3 × 4 = 20).
  static (String?, String?) _calc(List<String> toks) {
    var acc = double.parse(toks.first);
    for (var i = 1; i + 1 < toks.length; i += 2) {
      final b = double.parse(toks[i + 1]);
      switch (toks[i]) {
        case '+':
          acc += b;
        case '−':
          acc -= b;
        case '×':
          acc *= b;
        case '÷':
          if (b == 0) return (null, "Can't divide by 0");
          acc /= b;
      }
    }
    if (acc.isNaN || acc.isInfinite) return (null, 'Error');
    return (_num(acc), null);
  }

  /// 15 significant digits, no trailing zeros.
  static String _num(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    var s = double.parse(v.toStringAsPrecision(15)).toString();
    if (s.contains('e')) return s;
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  /// 12193209765585 → 12,193,209,765,585; very large or small → 1.2193210 × 10¹³.
  static String fmt(String t) {
    if (t.isEmpty || t == '-') return t.isEmpty ? '0' : t;
    final n = double.tryParse(t);
    if (n == null) return t;
    if (n.abs() >= 1e15 || (n != 0 && n.abs() < 1e-9)) {
      final parts = n.toStringAsExponential(8).split('e');
      const sup = '⁰¹²³⁴⁵⁶⁷⁸⁹';
      final e = int.parse(parts[1]).toString().split('').map((d) => d == '-' ? '⁻' : sup[int.parse(d)]).join();
      return '${parts[0].replaceFirst(RegExp(r'\.?0+$'), '').replaceFirst('-', '−')} × 10$e';
    }
    final dot = t.indexOf('.');
    final i = dot < 0 ? t : t.substring(0, dot), d = dot < 0 ? null : t.substring(dot + 1);
    final neg = i.startsWith('-'), digits = neg ? i.substring(1) : i;
    final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${neg ? '−' : ''}$grouped${d != null ? '.$d' : ''}';
  }
}

class _Calculator extends StatefulWidget {
  const _Calculator({this.compact = false, this.onClose});

  /// The floating Windows panel: smaller keys, no title (the panel has one), typing on the keyboard.
  final bool compact;
  final VoidCallback? onClose;
  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  final _e = CalcEngine();
  final _focus = FocusNode(debugLabel: 'calculator');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Keyboard on Windows: digits, . , + - * / x, %, Enter or =, Backspace, Delete or C to clear, Esc to close.
  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final ch = e.character;
    final k = e.logicalKey;
    String? press;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      press = '=';
    } else if (k == LogicalKeyboardKey.backspace) {
      press = '⌫';
    } else if (k == LogicalKeyboardKey.delete) {
      press = 'C';
    } else if (k == LogicalKeyboardKey.escape) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    } else if (ch != null && ch.isNotEmpty) {
      press = switch (ch) {
        '+' => '+',
        '-' => '−',
        '*' || 'x' || 'X' => '×',
        '/' => '÷',
        '%' => '%',
        '=' => '=',
        '.' || ',' => '.',
        'c' || 'C' => 'C',
        _ => RegExp(r'^\d$').hasMatch(ch) ? ch : null,
      };
    }
    if (press == null) return KeyEventResult.ignored;
    setState(() => _e.press(press!));
    return KeyEventResult.handled;
  }

  static const _keys = ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '±', '0', '.', '='];
  static const _names = {'⌫': 'Delete', '±': 'Plus or minus', '÷': 'Divide', '×': 'Times', '−': 'Minus', '%': 'Percent', 'C': 'Clear'};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final small = widget.compact;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The sheet has its own close button (one X only).
        if (!small) Text('Calculator', style: context.ty.h3),
        Container(
          height: small ? 100 : 108,
          margin: small ? const EdgeInsets.only(bottom: Space.s3) : const EdgeInsets.fromLTRB(0, Space.s3, 0, Space.s4),
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(_e.expression, style: context.ty.body.tnum.col(c.textMuted), semanticsLabel: 'Sum ${_e.expression}'),
              ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _e.display,
                    maxLines: 1,
                    style: _e.isError
                        ? context.ty.h2.copyWith(fontSize: 22).col(c.error)
                        : context.ty.display.copyWith(fontSize: small ? 32 : 40, height: 1.15, letterSpacing: -.5).tnum,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: small ? 6 : 8,
          crossAxisSpacing: small ? 6 : 8,
          childAspectRatio: small ? 1.5 : 1.45,
          children: [
            for (final k in _keys)
              Semantics(
                button: true,
                label: _names[k] ?? k,
                child: Pressable(
                  scale: .94,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _e.press(k)),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: k == '='
                          ? c.primary
                          : '÷×−+%'.contains(k)
                          ? c.secondarySoft
                          : c.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        k,
                        style: context.ty.h2
                            .copyWith(fontSize: small ? 17 : 20)
                            .col(
                              k == '='
                                  ? c.onPrimary
                                  : '÷×−+%'.contains(k)
                                  ? c.onSecondarySoft
                                  : c.text,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    if (!small) return body;
    return Focus(focusNode: _focus, autofocus: true, onKeyEvent: _key, child: body);
  }
}
