import 'package:solfare/features/swap/domain/entities/swap_token.dart';

/// How much of a balance a swap may actually spend.
class SwapLimits {
  const SwapLimits._();

  /// Native SOL held back from a swap to cover the signature, the priority bid,
  /// and the rent for any token account the route has to open.
  static const double solFeeReserve = 0.01;

  static bool isNativeSol(SwapToken token) => token.mint == SwapToken.sol.mint;

  /// What is left after the reserve.
  static double maxSpendable({required double balance, required bool nativeSol}) {
    if (!nativeSol) return balance < 0 ? 0 : balance;
    final left = balance - solFeeReserve;
    return left > 0 ? left : 0;
  }

  /// Whether [amount] fits.
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
