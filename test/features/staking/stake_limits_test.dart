import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/staking/domain/stake_limits.dart';

void main() {
  test('max leaves the rent deposit and the fees behind', () {
    // The bug: Max filled in the whole balance, and the transaction needs
    // amount + rent + two signatures. It could never land.
    expect(StakeLimits.maxStakeable(2.0), 2.0 - StakeLimits.totalReserve);
    expect(StakeLimits.maxStakeable(2.0), lessThan(2.0));
  });

  test('the reserve covers rent, which is the part that was missing', () {
    expect(StakeLimits.totalReserve, greaterThan(StakeLimits.feeReserve));
    expect(StakeLimits.rentReserve, greaterThan(0));
  });

  test('a balance under the reserve is nothing stakeable, not a debt', () {
    expect(StakeLimits.maxStakeable(0.001), 0);
    expect(StakeLimits.maxStakeable(0), 0);
  });

  test('max is always something the balance actually covers', () {
    for (final balance in [0.0, 0.005, 0.02, 1.0, 250.0]) {
      final max = StakeLimits.maxStakeable(balance);
      if (max > 0) {
        expect(StakeLimits.covers(amount: max, balance: balance), isTrue,
            reason: 'Max must be stakeable at a balance of $balance');
      }
    }
  });

  test('an amount within the reserve of the balance is refused', () {
    // Every stake in this band used to be offered and then fail on chain.
    expect(StakeLimits.covers(amount: 1.999, balance: 2.0), isFalse);
    expect(StakeLimits.covers(amount: 2.0, balance: 2.0), isFalse);
  });

  test('zero and negative amounts are not stakes', () {
    expect(StakeLimits.covers(amount: 0, balance: 10), isFalse);
    expect(StakeLimits.covers(amount: -1, balance: 10), isFalse);
  });

  test('a comfortable amount is allowed', () {
    expect(StakeLimits.covers(amount: 1.0, balance: 2.0), isTrue);
  });
}
