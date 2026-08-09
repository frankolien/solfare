import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/bloc/buy_state.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

void main() {
  const asset = MarketToken(
    id: 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W',
    name: 'SP500 xStock',
    symbol: 'SPYx',
    imageUrl: '',
    currentPrice: 773.75,
    decimals: 8,
  );

  BuyState state({
    String amount = '',
    double? balance,
    SwapToken payWith = SwapToken.sol,
    int? quotedOutRaw,
  }) =>
      BuyState(
        asset: asset,
        walletAddress: '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB',
        payWith: payWith,
        amountText: amount,
        balance: balance,
        quotedOutRaw: quotedOutRaw,
      );

  group('spendable', () {
    test('SOL keeps a reserve back for the fee and the token account rent', () {
      expect(state(balance: 1).spendable, closeTo(0.99, 1e-9));
    });

    test('a balance under the reserve is nothing spendable, not a negative', () {
      expect(state(balance: 0.004).spendable, 0);
    });

    test('a token balance is spendable in full — the fee is paid in SOL', () {
      expect(state(balance: 50, payWith: SwapToken.usdc).spendable, 50);
    });
  });

  group('hasEnough', () {
    test('spending into the reserve is blocked', () {
      expect(state(amount: '0.995', balance: 1).hasEnough, isFalse);
      expect(state(amount: '0.98', balance: 1).hasEnough, isTrue);
    });

    test('an unknown balance does not block the button', () {
      // The simulation is what actually knows, and it runs before anything is
      // broadcast. Blocking on a failed balance lookup would be a dead button
      // on a wallet with plenty in it.
      expect(state(amount: '5').hasEnough, isTrue);
    });

    test('no amount typed is not insufficient', () {
      expect(state(balance: 0).hasEnough, isTrue);
    });
  });

  group('canReview', () {
    test('needs an amount that the balance covers', () {
      expect(state(amount: '0.1', balance: 1).canReview, isTrue);
      expect(state(amount: '5', balance: 1).canReview, isFalse);
      expect(state(balance: 1).canReview, isFalse);
    });

    test('zero and junk are not amounts', () {
      expect(state(amount: '0', balance: 1).canReview, isFalse);
      expect(state(amount: '.', balance: 1).canReview, isFalse);
      expect(state(amount: '-1', balance: 1).canReview, isFalse);
    });

    test('review is not offered again once the route is being prepared', () {
      final preparing = state(amount: '0.1', balance: 1).copyWith(
        status: BuyStatus.preparing,
      );
      expect(preparing.canReview, isFalse);
    });
  });

  group('receiveAmount', () {
    test('base units are scaled by the asset decimals, not the payment ones', () {
      // 0.00012934 SPYx at 8dp.
      expect(state(quotedOutRaw: 12934).receiveAmount, closeTo(0.00012934, 1e-12));
    });

    test('no quote means nothing to show, not zero', () {
      expect(state().receiveAmount, isNull);
    });
  });

  test('switching what you pay with drops the old balance rather than reusing it', () {
    final sol = state(balance: 1.5);
    final usdc = sol.copyWith(payWith: SwapToken.usdc, clearBalance: true);
    expect(usdc.balance, isNull,
        reason: 'a SOL balance shown under USDC would be a lie');
  });
}
