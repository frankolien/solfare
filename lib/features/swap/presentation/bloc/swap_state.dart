import 'package:equatable/equatable.dart';
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
  });

  SwapReady copyWith({
    List<SwapToken>? tokens,
    SwapToken? inputToken,
    SwapToken? outputToken,
    String? inputAmount,
    String? outputAmount,
    double? priceImpact,
    double? rate,
    bool? isLoadingQuote,
    String? error,
  }) {
    return SwapReady(
      tokens: tokens ?? this.tokens,
      inputToken: inputToken ?? this.inputToken,
      outputToken: outputToken ?? this.outputToken,
      inputAmount: inputAmount ?? this.inputAmount,
      outputAmount: outputAmount ?? this.outputAmount,
      priceImpact: priceImpact ?? this.priceImpact,
      rate: rate ?? this.rate,
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      error: error,
    );
  }

  @override
  List<Object?> get props => [tokens, inputToken, outputToken, inputAmount, outputAmount, priceImpact, rate, isLoadingQuote, error];
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
