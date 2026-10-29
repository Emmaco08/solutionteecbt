import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/cbt/calculator.dart';

void main() {
  CalcEngine run(String keys) {
    final e = CalcEngine();
    for (final k in keys.split(' ')) {
      switch (k) {
        case '+' || '−' || '×' || '÷':
          e.op(k);
        case '=':
          e.equals();
        case '%':
          e.percent();
        case '±':
          e.sign();
        case '⌫':
          e.back();
        case 'C':
          e.clear();
        default:
          for (final d in k.split('')) {
            e.digit(d);
          }
      }
    }
    return e;
  }

  test('basic sums', () {
    expect(run('12 + 30 =').display, '42');
    expect(run('7 − 10 =').display, '-3');
    expect(run('6 × 7 =').display, '42');
    expect(run('1 ÷ 4 =').display, '0.25');
  });

  test('chains left to right, like a simple calculator', () {
    expect(run('2 + 3 × 4 =').display, '20');
  });

  test('decimals, percent, sign and backspace', () {
    expect(run('0.1 + 0.2 =').display, '0.3');
    expect(run('50 %').display, '0.5');
    expect(run('5 ±').display, '-5');
    expect(run('123 ⌫').display, '12');
    expect(run('1.2.3').display, '1.23');
  });

  test('divide by zero shows Error, and the next digit starts over', () {
    final e = run('5 ÷ 0 =');
    expect(e.display, 'Error');
    e.digit('7');
    expect(e.display, '7');
  });
}
