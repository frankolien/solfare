/// How much of a SOL balance a delegation may actually stake.
///
/// Staking costs more than the amount staked, and the difference is not
/// small enough to ignore. Every stake needs a brand new account, and that
/// account has to be funded past the rent-exempt threshold or the runtime
/// purges it — so the debit is amount + rent + fees, while the screen was
/// offering the whole balance as "Max" and calling the fee 0.000023205 SOL.
class StakeLimits {
  const StakeLimits._();

  /// A stake account is 200 bytes (`StakeProgram.neededAccountSpace`), which
  /// at the standard rent parameters needs 0.00228288 SOL to be exempt.
  ///
  /// Rent is a network parameter, so this is the figure to show and to budget
  /// against, not the one to send: StakingBloc reads the live value from
  /// getMinimumBalanceForRentExemption when it builds the transaction. Being
  /// slightly stale here can only make Max conservative, which is the safe
  /// direction to be wrong in.
  static const double rentReserve = 0.00228288;

  /// Held back for the two signatures (the wallet and the new stake account
  /// both sign) plus a priority bid. Matches SwapLimits.solFeeReserve so the
  /// two "leave enough behind" numbers cannot drift apart.
  static const double feeReserve = 0.01;

  static const double totalReserve = rentReserve + feeReserve;

  /// What is left to stake. Never negative: a balance under the reserve is
  /// nothing stakeable, not a debt.
  static double maxStakeable(double balance) {
    final left = balance - totalReserve;
    return left > 0 ? left : 0;
  }

  static bool covers({required double amount, required double balance}) {
    if (amount <= 0) return false;
    return amount <= maxStakeable(balance);
  }

  /// A validator's total stake, short enough for a row.
  ///
  /// Shared so the stake screen and the validator picker it opens cannot
  /// disagree about one validator's number — they did: 12,345 on one and
  /// 12.3K on the other.
  static String formatStake(double sol) {
    if (sol >= 1000000) return '${(sol / 1000000).toStringAsFixed(1)}M';
    if (sol >= 1000) return '${(sol / 1000).toStringAsFixed(1)}K';
    return sol.toStringAsFixed(0);
  }
}
