/// How much of a SOL balance a delegation may actually stake.
class StakeLimits {
  const StakeLimits._();

  /// A stake account is 200 bytes (`StakeProgram.neededAccountSpace`), which at
  /// the standard rent parameters needs 0.00228288 SOL to be exempt.
  static const double rentReserve = 0.00228288;

  /// Held back for the two signatures (the wallet and the new stake account
  /// both sign) plus a priority bid.
  static const double feeReserve = 0.01;

  static const double totalReserve = rentReserve + feeReserve;

  /// What is left to stake.
  static double maxStakeable(double balance) {
    final left = balance - totalReserve;
    return left > 0 ? left : 0;
  }

  static bool covers({required double amount, required double balance}) {
    if (amount <= 0) return false;
    return amount <= maxStakeable(balance);
  }

  /// A validator's total stake, short enough for a row.
  static String formatStake(double sol) {
    if (sol >= 1000000) return '${(sol / 1000000).toStringAsFixed(1)}M';
    if (sol >= 1000) return '${(sol / 1000).toStringAsFixed(1)}K';
    return sol.toStringAsFixed(0);
  }
}
