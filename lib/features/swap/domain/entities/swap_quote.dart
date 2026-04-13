import 'package:solfare/features/swap/domain/entities/swap_token.dart';

class SwapQuote {
  final SwapToken inputToken;
  final SwapToken outputToken;
  final double inputAmount;
  final double outputAmount;
  final double priceImpact;
  final double minimumReceived;
  final double slippageBps;
  final String swapTransaction; // base64 serialized transaction from Jupiter

  const SwapQuote({
    required this.inputToken,
    required this.outputToken,
    required this.inputAmount,
    required this.outputAmount,
    required this.priceImpact,
    required this.minimumReceived,
    required this.slippageBps,
    required this.swapTransaction,
  });

  String get rate {
    if (inputAmount == 0) return '0';
    return (outputAmount / inputAmount).toStringAsFixed(6);
  }
}
