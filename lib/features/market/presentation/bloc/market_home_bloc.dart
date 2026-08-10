import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/data/watchlist_store.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_state.dart';

class MarketHomeBloc extends Bloc<MarketHomeEvent, MarketHomeState> {
  final JupiterTokenDataSource _source;
  final WatchlistStore _watchlist;

  /// Long enough that leaving and coming back is free, short enough that the
  /// prices on a market screen are still prices.
  static const Duration cacheTtl = Duration(seconds: 45);

  final Map<MarketSection, _Cached> _cache = {};

  // Bumped per load so a slow section from an abandoned refresh cannot land on
  // top of a newer one.
  int _loadId = 0;

  StreamSubscription<void>? _watchlistSubscription;

  MarketHomeBloc({JupiterTokenDataSource? source, WatchlistStore? watchlist})
      : _source = source ?? JupiterTokenDataSource(),
        _watchlist = watchlist ?? WatchlistStore.instance,
        super(const MarketHomeState()) {
    on<MarketHomeRequested>(_onRequested);
    on<MarketHomeSectionLoaded>(_onSectionLoaded);
    on<MarketHomeWatchlistChanged>(_onWatchlistChanged);

    _watchlist.mints.addListener(_onStarsChanged);
  }

  @override
  Future<void> close() {
    _watchlist.mints.removeListener(_onStarsChanged);
    _watchlistSubscription?.cancel();
    return super.close();
  }

  void _onStarsChanged() {
    if (isClosed) return;
    add(MarketHomeWatchlistChanged(_watchlist.mints.value));
  }

  Future<void> _onRequested(MarketHomeRequested event, Emitter<MarketHomeState> emit) async {
    final id = ++_loadId;
    await _watchlist.load();

    final remote = MarketSection.home.where((s) => !s.isWatchlist).toList();
    emit(state.copyWith(loading: remote.toSet(), failed: const {}));

    // Kicked off together, not awaited together.
    for (final section in remote) {
      unawaited(_load(section, id, force: event.force));
    }

    add(MarketHomeWatchlistChanged(_watchlist.mints.value));
  }

  Future<void> _load(MarketSection section, int id, {required bool force}) async {
    final cached = _cache[section];
    if (!force && cached != null && cached.isFresh) {
      if (id == _loadId && !isClosed) add(MarketHomeSectionLoaded(section, cached.tokens));
      return;
    }

    try {
      final feed = section.feed;
      final shelf = section.shelf;
      final List<MarketToken> tokens;
      if (feed != null) {
        tokens = await _source.feed(feed, MarketWindow.h24, limit: 50);
      } else if (shelf != null) {
        tokens = (await _source.shelf(shelf)).tokens;
      } else {
        return;
      }

      if (id != _loadId || isClosed) return;
      _cache[section] = _Cached(tokens);
      add(MarketHomeSectionLoaded(section, tokens));
    } catch (e) {
      debugLog('[MarketHome] ${section.name} failed: $e');
      if (id != _loadId || isClosed) return;
      add(MarketHomeSectionLoaded(section, null));
    }
  }

  void _onSectionLoaded(MarketHomeSectionLoaded event, Emitter<MarketHomeState> emit) {
    final loading = {...state.loading}..remove(event.section);
    final failed = {...state.failed};
    final sections = {...state.sections};

    if (event.tokens == null) {
      failed.add(event.section);
    } else {
      failed.remove(event.section);
      sections[event.section] = event.tokens!;
    }

    emit(state.copyWith(sections: sections, loading: loading, failed: failed));
  }

  Future<void> _onWatchlistChanged(
    MarketHomeWatchlistChanged event,
    Emitter<MarketHomeState> emit,
  ) async {
    if (event.mints.isEmpty) {
      emit(state.copyWith(sections: {...state.sections, MarketSection.watchlist: const []}));
      return;
    }

    // Most stars are put on something already on screen, so the redraw costs
    // nothing.
    final known = state.byMint;
    final resolved = [
      for (final mint in event.mints)
        if (known[mint] case final MarketToken token) token,
    ];
    emit(state.copyWith(
      sections: {...state.sections, MarketSection.watchlist: resolved},
    ));

    final missing = event.mints.where((mint) => !known.containsKey(mint)).toList();
    if (missing.isEmpty) return;

    try {
      final fetched = await _source.hydrate(missing);
      if (isClosed) return;
      final byMint = {...known, for (final token in fetched.tokens) token.id: token};
      // Re-read the live list: a star may have moved while this was in flight.
      final current = _watchlist.mints.value;
      emit(state.copyWith(sections: {
        ...state.sections,
        MarketSection.watchlist: [
          for (final mint in current)
            if (byMint[mint] case final MarketToken token) token,
        ],
      }));
    } catch (e) {
      debugLog('[MarketHome] watchlist hydrate failed: $e');
    }
  }
}

class _Cached {
  final List<MarketToken> tokens;
  final DateTime at;

  _Cached(this.tokens) : at = DateTime.now();

  bool get isFresh => DateTime.now().difference(at) < MarketHomeBloc.cacheTtl;
}
