import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/lamports.dart';

void main() {
  test('rounds rather than truncates', () {
    // Measured: 0.000065 * 1e9 is 64999.99999999999, so toInt() sends 64999
    // lamports for an amount the user entered as 65000. This is the drift
    // staking_bloc had and wallet_bloc did not.
    expect((0.000065 * Lamports.perSol).toInt(), 64999,
        reason: 'the wrong answer this exists to prevent');
    expect(Lamports.fromSol(0.000065), 65000);
  });

  test('every amount a user can type survives the conversion exactly', () {
    // Six decimal places is what the amount keypads allow. Sweeping them is
    // cheap and catches the next float that lands a hair under an integer.
    for (var i = 1; i <= 200000; i++) {
      final sol = i / 1000000;
      expect(Lamports.fromSol(sol), i * 1000,
          reason: '$sol SOL should be exactly ${i * 1000} lamports');
    }
  });

  test('round-trips a whole SOL', () {
    expect(Lamports.fromSol(1), Lamports.perSol);
    expect(Lamports.toSol(Lamports.perSol), 1.0);
  });

  test('zero is zero in both directions', () {
    expect(Lamports.fromSol(0), 0);
    expect(Lamports.toSol(0), 0.0);
  });

  test('a single lamport survives the trip out and back', () {
    expect(Lamports.fromSol(Lamports.toSol(1)), 1);
  });

  test('the rent-exempt minimum for a stake account is not lost', () {
    // 0.00228288 SOL. Truncation here is what made "Max" unstakeable.
    expect(Lamports.fromSol(0.00228288), 2282880);
  });
}
