import 'package:equatable/equatable.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

abstract class SwapState extends Equatable {
  const SwapState();
  @override
  List<Object?> get props => [];
}

class SwapInitial extends SwapState {
  const SwapInitial();
}

class SwapLoading extends SwapState {
  const SwapLoading();
}

class SwapReady extends SwapState {
  final List<SwapToken> tokens;
  final SwapToken inputToken;
  final SwapToken outputToken;
  final String inputAmount;
  final String? outputAmount;
  final double? priceImpact;
  final double? rate; // output per 1 input
  final bool isLoadingQuote;
  final String? error;

  /// Wallet balance of [inputToken], null until it has been fetched.
  final double? inputBalance;

  const SwapReady({
    required this.tokens,
    required this.inputToken,
    required this.outputToken,
    this.inputAmount = '',
    this.outputAmount,
    this.priceImpact,
    this.rate,
    this.isLoadingQuote = false,
    this.error,
    this.inputBalance,
  });

  // Distinguishes "leave this alone" from "set this to null".
  static const _keep = Object();

  SwapReady copyWith({
    List<SwapToken>? tokens,
    SwapToken? inputToken,
    SwapToken? outputToken,
    String? inputAmount,
    Object? outputAmount = _keep,
    Object? priceImpact = _keep,
    Object? rate = _keep,
    bool? isLoadingQuote,
    String? error,
    Object? inputBalance = _keep,
  }) {
    return SwapReady(
      tokens: tokens ?? this.tokens,
      inputToken: inputToken ?? this.inputToken,
      outputToken: outputToken ?? this.outputToken,
      inputAmount: inputAmount ?? this.inputAmount,
      outputAmount:
          identical(outputAmount, _keep) ? this.outputAmount : outputAmount as String?,
      priceImpact:
          identical(priceImpact, _keep) ? this.priceImpact : priceImpact as double?,
      rate: identical(rate, _keep) ? this.rate : rate as double?,
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      error: error,
      inputBalance:
          identical(inputBalance, _keep) ? this.inputBalance : inputBalance as double?,
    );
  }

  @override
  List<Object?> get props => [tokens, inputToken, outputToken, inputAmount, outputAmount, priceImpact, rate, isLoadingQuote, error, inputBalance];
}

/// The route is built and signed, and the network has said what it will do.
class SwapReviewing extends SwapState {
  final SwapReady ready;
  final TxPreview preview;

  const SwapReviewing({required this.ready, required this.preview});

  @override
  List<Object?> get props => [ready, preview];
}

class SwapExecuting extends SwapState {
  const SwapExecuting();
}

class SwapSuccess extends SwapState {
  final String transactionId;
  const SwapSuccess(this.transactionId);
  @override
  List<Object?> get props => [transactionId];
}

class SwapError extends SwapState {
  final String message;
  const SwapError(this.message);
  @override
  List<Object?> get props => [message];
}
