import 'package:equatable/equatable.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

abstract class SwapEvent extends Equatable {
  const SwapEvent();
  @override
  List<Object?> get props => [];
}

class LoadTokenListEvent extends SwapEvent {
  /// Whose holdings to put at the top of the list. Null falls back to the
  /// curated set, which is all a screen without an address can offer.
  final String? walletAddress;

  const LoadTokenListEvent({this.walletAddress});

  @override
  List<Object?> get props => [walletAddress];
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

/// Fetch the wallet's balance of whichever token is currently selected as the
/// input, so the swap button can tell "no balance" from "no quote".
class LoadInputBalanceEvent extends SwapEvent {
  final String walletAddress;
  const LoadInputBalanceEvent(this.walletAddress);
  @override
  List<Object?> get props => [walletAddress];
}

class FlipTokensEvent extends SwapEvent {
  const FlipTokensEvent();
}

/// Send the route the user just reviewed.
class ConfirmSwapEvent extends SwapEvent {
  const ConfirmSwapEvent();
}

/// Back out of the review.
class CancelSwapReviewEvent extends SwapEvent {
  const CancelSwapReviewEvent();
}
