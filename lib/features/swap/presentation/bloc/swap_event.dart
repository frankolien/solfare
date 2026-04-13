import 'package:equatable/equatable.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

abstract class SwapEvent extends Equatable {
  const SwapEvent();
  @override
  List<Object?> get props => [];
}

class LoadTokenListEvent extends SwapEvent {
  const LoadTokenListEvent();
}

class SelectInputTokenEvent extends SwapEvent {
  final SwapToken token;
  const SelectInputTokenEvent(this.token);
  @override
  List<Object?> get props => [token];
}

class SelectOutputTokenEvent extends SwapEvent {
  final SwapToken token;
  const SelectOutputTokenEvent(this.token);
  @override
  List<Object?> get props => [token];
}

class UpdateInputAmountEvent extends SwapEvent {
  final String amount;
  const UpdateInputAmountEvent(this.amount);
  @override
  List<Object?> get props => [amount];
}

class SwapTokensEvent extends SwapEvent {
  const SwapTokensEvent();
}

class FetchQuoteEvent extends SwapEvent {
  const FetchQuoteEvent();
}

class ExecuteSwapEvent extends SwapEvent {
  final String walletAddress;
  const ExecuteSwapEvent(this.walletAddress);
  @override
  List<Object?> get props => [walletAddress];
}

class FlipTokensEvent extends SwapEvent {
  const FlipTokensEvent();
}
