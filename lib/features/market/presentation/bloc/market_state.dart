import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

abstract class MarketState extends Equatable {
  const MarketState();

  @override
  List<Object?> get props => [];
}

class MarketInitial extends MarketState {
  const MarketInitial();
}

class MarketLoading extends MarketState {
  const MarketLoading();
}

class MarketLoaded extends MarketState {
  final List<MarketToken> tokens;

  const MarketLoaded(this.tokens);

  @override
  List<Object?> get props => [tokens];
}

class MarketError extends MarketState {
  final String message;

  const MarketError(this.message);

  @override
  List<Object?> get props => [message];
}
