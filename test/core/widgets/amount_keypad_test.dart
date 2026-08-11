import 'package:flutter/material.dart';
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

  group('hit target', () {
    testWidgets('a tap near the edge of a key still registers', (tester) async {
      // The bug: GestureDetector defaults to deferToChild, and a bare SizedBox
      // paints nothing — so only the glyph was hit-testable and the user had
      // to land on the digit itself.
      final pressed = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmountKeypad(onDigit: pressed.add, onDelete: () {}),
        ),
      ));

      final key = tester.getRect(find.text('9'));
      final box = tester.getRect(
        find.ancestor(of: find.text('9'), matching: find.byType(SizedBox)).first,
      );
      expect(box.width, greaterThan(key.width * 2),
          reason: 'the key is much larger than its glyph');

      // A corner of the key, well outside the character.
      await tester.tapAt(Offset(box.left + 4, box.top + 4));
      await tester.pump();

      expect(pressed, ['9']);
    });

    testWidgets('every digit and the point are reachable', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmountKeypad(onDigit: pressed.add, onDelete: () {}),
        ),
      ));

      for (final label in ['1', '5', '9', '0', '.']) {
        await tester.tap(find.text(label));
      }
      await tester.pump();

      expect(pressed, ['1', '5', '9', '0', '.']);
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
