import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/domain/swap_limits.dart';

void main() {
  group('maxSpendable', () {
    test('SOL keeps a reserve back for the fee and the token account rent', () {
      expect(SwapLimits.maxSpendable(balance: 1, nativeSol: true), closeTo(0.99, 1e-9));
    });

    test('a balance under the reserve is nothing spendable, not a negative', () {
      expect(SwapLimits.maxSpendable(balance: 0.004, nativeSol: true), 0);
    });

    test('a token balance is spendable in full — the fee is paid in SOL', () {
      expect(SwapLimits.maxSpendable(balance: 50, nativeSol: false), 50);
    });
  });

  group('covers', () {
    test('spending into the reserve is blocked', () {
      expect(SwapLimits.covers(amount: 0.995, balance: 1, nativeSol: true), isFalse);
      expect(SwapLimits.covers(amount: 0.98, balance: 1, nativeSol: true), isTrue);
    });

    test('an unknown balance does not block the button', () {
      expect(SwapLimits.covers(amount: 5, balance: null, nativeSol: true), isTrue,
          reason: 'the simulation is what knows, and it runs before anything is sent');
    });

    test('zero and negative are not amounts', () {
      expect(SwapLimits.covers(amount: 0, balance: 10, nativeSol: false), isFalse);
      expect(SwapLimits.covers(amount: -1, balance: 10, nativeSol: false), isFalse);
    });

    test('an empty wallet covers nothing', () {
      expect(SwapLimits.covers(amount: 0.001, balance: 0, nativeSol: true), isFalse);
    });
  });

  test('native SOL is recognised by its mint, not by its ticker', () {
    expect(SwapLimits.isNativeSol(SwapToken.sol), isTrue);
    expect(SwapLimits.isNativeSol(SwapToken.usdc), isFalse);
    // A token wearing the SOL ticker is still not native SOL.
    const impostor = SwapToken(
      mint: 'So1111111111111111111111111111111111111113',
      symbol: 'SOL',
      name: 'Not Solana',
      decimals: 9,
    );
    expect(SwapLimits.isNativeSol(impostor), isFalse);
  });
}
