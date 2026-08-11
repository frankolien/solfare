import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/widgets/amount_keypad.dart';

void main() {
  group('appending', () {
    test('a leading zero is replaced, not prefixed', () {
      expect(appendDigit('0', '5'), '5');
    });

    test('a zero before a point is kept', () {
      expect(appendDigit(appendDigit('0', '.'), '5'), '0.5');
    });

    test('a point on an empty field opens with zero', () {
      expect(appendDigit('', '.'), '0.');
    });

    test('a second point is refused', () {
      expect(appendDigit('1.5', '.'), '1.5');
    });

    test('the fraction is bounded, since lamports stop at nine places', () {
      var value = '1.';
      for (var i = 0; i < 12; i++) {
        value = appendDigit(value, '1');
      }
      expect(value.split('.').last.length, 9);
    });

    test('the whole part is not bounded by the fraction limit', () {
      expect(appendDigit('123456789012', '3'), '1234567890123');
    });
  });

  group('deleting', () {
    test('takes one character', () {
      expect(removeDigit('1.5'), '1.');
    });

    test('deleting down to a lone zero clears the field', () {
      // Otherwise the field reads "0" and the hint never comes back.
      expect(removeDigit('10'), '1');
      expect(removeDigit('0'), '');
    });

    test('an empty field stays empty', () {
      expect(removeDigit(''), '');
    });
  });
}
