import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

abstract class MarketEvent extends Equatable {
  const MarketEvent();

  @override
  List<Object?> get props => [];
}

/// Load the section this bloc was opened on.
class FetchMarketTokensEvent extends MarketEvent {
  final bool force;

  const FetchMarketTokensEvent({this.force = false});

  @override
  List<Object?> get props => [force];
}

class SelectWindowEvent extends MarketEvent {
  final MarketWindow window;

  const SelectWindowEvent(this.window);

  @override
  List<Object?> get props => [window];
}

/// Selecting the key already in use flips its direction; a different key starts
/// descending.
class SelectSortEvent extends MarketEvent {
  final MarketSort sort;

  const SelectSortEvent(this.sort);

  @override
  List<Object?> get props => [sort];
}
