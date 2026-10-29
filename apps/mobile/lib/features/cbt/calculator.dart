import 'package:flutter/material.dart';

import '../../widgets/phosphor.g.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';

/// A basic four-function calculator, like the one on the JAMB CBT screen.
void showCalculator(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (_) => const _Calculator());

/// Pure calculator logic, kept apart from the UI so it can be unit tested.
class CalcEngine {
  String display = '0';
  double? _acc;
  String? _op;
  bool _fresh = true;

  void digit(String d) {
    if (display == 'Error') clear();
    if (_fresh) {
      display = d == '.' ? '0.' : d;
      _fresh = false;
    } else if (d == '.' && display.contains('.')) {
      return;
    } else if (display.length < 14) {
      display = display == '0' && d != '.' ? d : display + d;
    }
  }

  void op(String o) {
    if (display == 'Error') return;
    if (_op != null && !_fresh) {
      equals();
      if (display == 'Error') return;
    }
    _acc = double.parse(display);
    _op = o;
    _fresh = true;
  }

  void equals() {
    if (_op == null || _acc == null) return;
    final b = double.parse(display);
    final r = switch (_op) {
      '+' => _acc! + b,
      '−' => _acc! - b,
      '×' => _acc! * b,
      _ => b == 0 ? double.nan : _acc! / b,
    };
    display = _format(r);
    _acc = null;
    _op = null;
    _fresh = true;
  }

  void percent() {
    if (display == 'Error') return;
    display = _format(double.parse(display) / 100);
    _fresh = true;
  }

  void sign() {
    if (display == 'Error' || display == '0') return;
    display = display.startsWith('-') ? display.substring(1) : '-$display';
  }

  void back() {
    if (_fresh || display == 'Error') return;
    display = display.length <= 1 || (display.length == 2 && display.startsWith('-')) ? '0' : display.substring(0, display.length - 1);
  }

  void clear() {
    display = '0';
    _acc = null;
    _op = null;
    _fresh = true;
  }

  static String _format(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.roundToDouble() && v.abs() < 1e14) return v.toInt().toString();
    var s = v.toStringAsPrecision(10);
    if (s.contains('e')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }
}

class _Calculator extends StatefulWidget {
  const _Calculator();
  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  final _e = CalcEngine();

  void _tap(String k) => setState(() {
    switch (k) {
      case 'C':
        _e.clear();
      case '⌫':
        _e.back();
      case '%':
        _e.percent();
      case '±':
        _e.sign();
      case '=':
        _e.equals();
      case '+' || '−' || '×' || '÷':
        _e.op(k);
      default:
        _e.digit(k);
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const keys = ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '±', '0', '.', '='];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.calculator(), size: 18, color: c.textMuted),
                gapW2,
                Text('Calculator', style: context.t.labelLarge),
              ],
            ),
            const SizedBox(height: Space.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _e.display,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: context.t.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
            const SizedBox(height: Space.s3),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: Space.s2,
              crossAxisSpacing: Space.s2,
              childAspectRatio: 1.6,
              children: [
                for (final k in keys)
                  Material(
                    color: k == '='
                        ? c.primary
                        : '÷×−+'.contains(k)
                        ? c.secondarySoft
                        : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () => _tap(k),
                      child: Center(
                        child: Text(
                          k,
                          style: context.t.titleMedium?.copyWith(
                            color: k == '='
                                ? c.onPrimary
                                : '÷×−+'.contains(k)
                                ? c.onSecondarySoft
                                : c.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const gapW2 = SizedBox(width: Space.s2);
