import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

abstract class MarketHomeEvent extends Equatable {
  const MarketHomeEvent();

  @override
  List<Object?> get props => [];
}

/// Load every section. [force] skips the cache, which is what pull-to-refresh
/// means.
class MarketHomeRequested extends MarketHomeEvent {
  final bool force;

  const MarketHomeRequested({this.force = false});

  @override
  List<Object?> get props => [force];
}

/// The starred mints changed. Redraws from what is already loaded where it
/// can, and only asks the API about mints the home has never seen.
class MarketHomeWatchlistChanged extends MarketHomeEvent {
  final List<String> mints;

  const MarketHomeWatchlistChanged(this.mints);

  @override
  List<Object?> get props => [mints];
}

/// Internal: one section came back. Routed through the event loop so the
/// emit happens inside a handler rather than after one has returned.
class MarketHomeSectionLoaded extends MarketHomeEvent {
  final MarketSection section;
  final List<MarketToken>? tokens;

  const MarketHomeSectionLoaded(this.section, this.tokens);

  @override
  List<Object?> get props => [section, tokens?.length];
}
