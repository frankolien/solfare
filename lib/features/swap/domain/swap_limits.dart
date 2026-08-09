import 'package:solfare/features/swap/domain/entities/swap_token.dart';

/// How much of a balance a swap may actually spend.
///
/// Its own file because getting it wrong is invisible until a swap the user
/// already approved fails on chain for want of a few thousand lamports.
class SwapLimits {
  const SwapLimits._();

  /// Native SOL held back from a swap to cover the signature, the priority
  /// bid, and the rent for any token account the route has to open. A first
  /// purchase of any asset opens one.
  static const double solFeeReserve = 0.01;

  static bool isNativeSol(SwapToken token) => token.mint == SwapToken.sol.mint;

  /// What is left after the reserve. Never negative: a balance under the
  /// reserve is nothing spendable, not a debt.
  static double maxSpendable({required double balance, required bool nativeSol}) {
    if (!nativeSol) return balance < 0 ? 0 : balance;
    final left = balance - solFeeReserve;
    return left > 0 ? left : 0;
  }

  /// Whether [amount] fits. An unknown balance is not a reason to block: the
  /// simulation is what actually knows, and it runs before anything is
  /// broadcast. Blocking on a failed lookup is a dead button on a full wallet.
  static bool covers({
    required double amount,
    required double? balance,
    required bool nativeSol,
  }) {
    if (amount <= 0) return false;
    if (balance == null) return true;
    return amount <= maxSpendable(balance: balance, nativeSol: nativeSol);
  }
}
