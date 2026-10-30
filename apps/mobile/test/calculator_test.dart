import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/cbt/calculator.dart';

void main() {
  CalcEngine run(String keys) {
    final e = CalcEngine();
    for (final k in keys.split(' ')) {
      if (k.length > 1 && RegExp(r'^[\d.]+$').hasMatch(k)) {
        for (final d in k.split('')) {
          e.press(d);
        }
      } else {
        e.press(k);
      }
    }
    return e;
  }

  test('basic sums, with the sum line on top', () {
    final e = run('12 + 30 =');
    expect(e.display, '42');
    expect(e.expression, '12 + 30 =');
    expect(run('7 − 10 =').display, '−3');
    expect(run('6 × 7 =').display, '42');
    expect(run('1 ÷ 4 =').display, '0.25');
  });

  test('chains left to right, like a simple calculator', () {
    expect(run('2 + 3 × 4 =').display, '20');
  });

  test('thousands separators and large numbers', () {
    expect(run('1234567 × 1000 =').display, '1,234,567,000');
    expect(run('999999999 × 999999999 =').display, contains('× 10'));
  });

  test('decimals, percent, sign, backspace and changing the operator', () {
    expect(run('0.1 + 0.2 =').display, '0.3');
    expect(run('50 %').display, '0.5');
    expect(run('5 ±').display, '−5');
    expect(run('123 ⌫').display, '12');
    expect(run('1.2.3').display, '1.23');
    expect(run('8 + × 2 =').display, '16');
  });

  test("divide by zero says so, and the next digit starts over", () {
    final e = run('5 ÷ 0 =');
    expect(e.display, "Can't divide by 0");
    expect(e.isError, isTrue);
    e.press('7');
    expect(e.display, '7');
  });
}
