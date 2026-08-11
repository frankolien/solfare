import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/widgets/shimmer.dart';
import 'package:solfare/features/homepage/presentation/widgets/balance_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  BalanceCard card({
    DateTime? staleSince,
    double price = 86.29,
    VoidCallback? onRetry,
    bool isLoading = false,
    double balance = 0.3523,
  }) =>
      BalanceCard(
        balanceInSol: balance,
        isLoading: isLoading,
        solPriceUsd: price,
        solPriceChange24h: 2.4,
        staleSince: staleSince,
        onRetry: onRetry,
      );

  testWidgets('a live balance carries no extra chrome', (tester) async {
    await tester.pumpWidget(host(card()));

    expect(find.textContaining('Updated'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('a failed refresh says when the figure was true', (tester) async {
    await tester.pumpWidget(host(card(
      staleSince: DateTime.now().subtract(const Duration(hours: 2)),
    )));

    expect(find.text('Updated 2h ago'), findsOneWidget);
  });

  testWidgets('the age is worded by scale', (tester) async {
    for (final (ago, expected) in [
      (const Duration(seconds: 20), 'Updated just now'),
      (const Duration(minutes: 5), 'Updated 5m ago'),
      (const Duration(hours: 3), 'Updated 3h ago'),
      (const Duration(days: 2), 'Updated 2d ago'),
    ]) {
      await tester.pumpWidget(host(card(
        staleSince: DateTime.now().subtract(ago),
      )));
      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('a clock that moved backwards does not read as the future',
      (tester) async {
    await tester.pumpWidget(host(card(
      staleSince: DateTime.now().add(const Duration(hours: 1)),
    )));

    expect(find.text('Updated just now'), findsOneWidget);
  });

  testWidgets('retry is offered beside the timestamp', (tester) async {
    var retried = 0;
    await tester.pumpWidget(host(card(
      staleSince: DateTime.now().subtract(const Duration(minutes: 5)),
      onRetry: () => retried++,
    )));

    await tester.tap(find.byIcon(Icons.refresh));
    expect(retried, 1);
  });

  testWidgets('an unknown balance shimmers, never reads zero', (tester) async {
    // "We do not know yet" rendered as 0 tells the user their wallet is empty,
    // in 32pt type, on the first screen they see.
    await tester.pumpWidget(host(card(isLoading: true, balance: 0, price: 0)));

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.textContaining('0.0000'), findsNothing);
    expect(find.textContaining(r'$0.00'), findsNothing);
  });

  testWidgets('the whole portfolio is the headline, not just SOL',
      (tester) async {
    // 1 SOL at $76 plus $24 of tokens is a $100 wallet. A card that counts only
    // SOL is wrong for anyone holding anything else.
    await tester.pumpWidget(host(BalanceCard(
      balanceInSol: 1,
      totalUsd: 100,
      portfolioChange24h: 2.5,
      isLoading: false,
      solPriceUsd: 76,
      solPriceChange24h: -1,
    )));

    expect(find.textContaining('1'), findsWidgets);
    expect(find.text('+2.50%'), findsOneWidget,
        reason: 'the change is portfolio-weighted, not SOL\'s own');
  });

  testWidgets('an inactive carousel page shows no figure at all', (tester) async {
    // What the swiper passes for a wallet that is not the active one.
    await tester.pumpWidget(host(card(isLoading: true, balance: 0, price: 0)));

    expect(find.textContaining('SOL'), findsNothing);
  });

  testWidgets('with no price it shows SOL rather than an invented dollar figure',
      (tester) async {
    // The old code multiplied by a hardcoded 86.29, which rendered a wrong
    // number as the user's money.
    await tester.pumpWidget(host(card(price: 0)));

    expect(find.text('0.3523 SOL'), findsOneWidget);
    expect(find.textContaining('\$'), findsNothing);
  });
}
