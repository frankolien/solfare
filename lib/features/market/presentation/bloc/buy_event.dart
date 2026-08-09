import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

abstract class BuyEvent extends Equatable {
  const BuyEvent();

  @override
  List<Object?> get props => [];
}

class BuyStarted extends BuyEvent {
  final MarketToken asset;
  final String walletAddress;

  const BuyStarted({required this.asset, required this.walletAddress});

  @override
  List<Object?> get props => [asset.id, walletAddress];
}

class BuyPayWithChanged extends BuyEvent {
  final SwapToken token;

  const BuyPayWithChanged(this.token);

  @override
  List<Object?> get props => [token.mint];
}

class BuyAmountChanged extends BuyEvent {
  final String amount;

  const BuyAmountChanged(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Build the route, sign it, and simulate what it does. Nothing is broadcast.
class BuyReviewRequested extends BuyEvent {
  const BuyReviewRequested();
}

class BuyReviewDismissed extends BuyEvent {
  const BuyReviewDismissed();
}

/// The only event that puts anything on the network.
class BuyConfirmed extends BuyEvent {
  const BuyConfirmed();
}
