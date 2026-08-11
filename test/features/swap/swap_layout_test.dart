import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/widgets/amount_keypad.dart';
import 'package:solfare/features/swap/presentation/swap_layout.dart';
import 'package:solfare/features/swap/presentation/widgets/amount_card.dart';

/// The swap screen budgets its height from constants, because a layout pass
/// cannot ask a sibling how tall it wants to be. These re-measure the widgets
/// those constants stand for, so a padding or font change fails here instead
/// of silently clipping a control off the screen.
void main() {
  // The homepage shell hands the swap screen this much on a 393x852 device:
  // 852 - 59 status bar - 20 shell padding - 91 nav bar.
  const shellHeight = 682.0;
  const headerHeight = 48.0;

  /// Renders [child] under an unbounded height, the way the scrolling half of
  /// the screen does, and reports what it asks for.
  Future<double> heightOf(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 393, child: child),
        ),
      ),
    ));
    return tester.getRect(find.byWidget(child)).height;
  }

  testWidgets('an amount card is as tall as the constant says', (tester) async {
    // The card the screen actually builds, not a copy of it — a copy drifts
    // without anything failing, which is how the budget went wrong.
    final card = AmountCard(
      label: 'SELL',
      amount: '0',
      dimmed: true,
      valueUsd: null,
      balance: 'Max: 0.008625',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          SizedBox(width: 28, height: 28),
          SizedBox(width: 8),
          Text('SOL', style: TextStyle(fontSize: 15)),
          Icon(Icons.keyboard_arrow_down, size: 18),
        ]),
      ),
    );

    expect(await heightOf(tester, card), SwapLayout.cardHeight);
  });

  testWidgets('the keypad is as tall as the constants say', (tester) async {
    final keypad = AmountKeypad(
      keyHeight: SwapLayout.maxKeyHeight,
      onDigit: (_) {},
      onDelete: () {},
    );
    final height = await heightOf(tester, keypad);

    // Four rows of keys with a gap between each.
    expect(height,
        SwapLayout.maxKeyHeight * 4 + SwapLayout.gap * 3);
  });

  testWidgets('a shorter key height shortens the keypad by as much',
      (tester) async {
    final tall = await heightOf(
        tester,
        AmountKeypad(
            keyHeight: 56, onDigit: (_) {}, onDelete: () {}));
    final short = await heightOf(
        tester,
        AmountKeypad(
            keyHeight: 44, onDigit: (_) {}, onDelete: () {}));

    expect(tall - short, (56 - 44) * 4);
  });

  testWidgets('a key stays big enough to hit at the floor', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AmountKeypad(
          keyHeight: SwapLayout.minKeyHeight,
          onDigit: (_) {},
          onDelete: () {},
        ),
      ),
    ));

    final key = tester.getRect(find.text('9'));
    final tappable = tester.getRect(find.ancestor(
        of: find.text('9'), matching: find.byType(SizedBox)));

    expect(tappable.height, greaterThanOrEqualTo(44),
        reason: 'the smallest comfortable target');
    expect(tappable.width, greaterThanOrEqualTo(44));
    expect(tappable.contains(key.center), isTrue);
  });

  test('the input band fits the screen with the cards left whole', () {
    final available = shellHeight - headerHeight;
    final keyHeight = SwapLayout.keyHeight(available);
    final band = SwapLayout.inputBand(keyHeight);

    // The regression: the pinned half used to be taller than what was left
    // after the cards, so the scroll view clipped through the percentage row.
    expect(band + SwapLayout.cardsBand, lessThanOrEqualTo(available));
    expect(keyHeight, greaterThanOrEqualTo(SwapLayout.minKeyHeight));
  });

  test('a short screen shrinks the keys before it shrinks them past use', () {
    // An iPhone SE: 667 - 20 - 20 - 65 nav bar, less the header.
    final keyHeight = SwapLayout.keyHeight(562 - headerHeight);

    expect(keyHeight, SwapLayout.minKeyHeight,
        reason: 'the floor holds, and the cards scroll instead');
  });

  test('a tall screen does not stretch the keys past their drawn size', () {
    expect(SwapLayout.keyHeight(2000), SwapLayout.maxKeyHeight);
  });
}
