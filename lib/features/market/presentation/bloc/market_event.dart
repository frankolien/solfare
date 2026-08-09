import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

abstract class MarketEvent extends Equatable {
  const MarketEvent();

  @override
  List<Object?> get props => [];
}

/// Load whatever the current selection points at. [force] skips the cache,
/// which is what pull-to-refresh means.
class FetchMarketTokensEvent extends MarketEvent {
  final bool force;

  const FetchMarketTokensEvent({this.force = false});

  @override
  List<Object?> get props => [force];
}

class SelectCategoryEvent extends MarketEvent {
  final MarketCategory category;

  const SelectCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class SelectFeedEvent extends MarketEvent {
  final MarketFeed feed;

  const SelectFeedEvent(this.feed);

  @override
  List<Object?> get props => [feed];
}

class SelectWindowEvent extends MarketEvent {
  final MarketWindow window;

  const SelectWindowEvent(this.window);

  @override
  List<Object?> get props => [window];
}

/// Selecting the key already in use flips its direction; a different key
/// adopts its own default.
class SelectSortEvent extends MarketEvent {
  final MarketSort sort;

  const SelectSortEvent(this.sort);

  @override
  List<Object?> get props => [sort];
}
