import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';

void main() {
  const quoted = SwapReady(
    tokens: [SwapToken.sol, SwapToken.usdc],
    inputToken: SwapToken.sol,
    outputToken: SwapToken.usdc,
    inputAmount: '1',
    outputAmount: '150.0000',
    rate: 150,
    priceImpact: 0.01,
    inputBalance: 12,
  );

  group('clearing a quote', () {
    test('passing null actually clears the output amount', () {
      // `x ?? this.x` could not tell "leave this alone" from "set to null",
      // so every attempt to clear was a no-op: change the buy token after
      // quoting 1 SOL and the review sheet still headlined 150.0000 of
      // whatever was picked, for a route paying something else entirely.
      final cleared = quoted.copyWith(outputToken: SwapToken.sol, outputAmount: null);
      expect(cleared.outputAmount, isNull);
    });

    test('the rate and the price impact clear too', () {
      final cleared = quoted.copyWith(rate: null, priceImpact: null);
      expect(cleared.rate, isNull);
      expect(cleared.priceImpact, isNull);
    });

    test('an unknown balance is representable', () {
      // Distinct from zero. A failed lookup that reads as zero shows
      // "Insufficient" on a funded wallet.
      final cleared = quoted.copyWith(inputBalance: null);
      expect(cleared.inputBalance, isNull);
    });

    test('omitting a field leaves it alone', () {
      final same = quoted.copyWith(inputAmount: '2');
      expect(same.outputAmount, '150.0000');
      expect(same.rate, 150);
      expect(same.priceImpact, 0.01);
      expect(same.inputBalance, 12);
    });

    test('a cleared quote is no quote', () {
      final cleared = quoted.copyWith(outputAmount: null);
      expect(cleared.outputAmount, isNull,
          reason: 'the swap button reads this to decide if it is enabled');
    });
  });
}
