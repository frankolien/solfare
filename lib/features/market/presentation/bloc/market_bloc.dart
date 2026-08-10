import 'package:bloc/bloc.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/data/watchlist_store.dart';
import 'package:solfare/features/market/domain/entities/market_feed_result.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';

/// One section, shown in full: every row, sortable, over any window.
///
/// Scoped to the screen that opens it rather than shared, because the list is
/// somewhere you go rather than somewhere the app keeps state for you.
class MarketBloc extends Bloc<MarketEvent, MarketState> {
  final JupiterTokenDataSource _source;
  final WatchlistStore _watchlist;

  /// Long enough that a window flick is free, short enough that the prices on
  /// a market screen are still prices.
  static const Duration cacheTtl = Duration(seconds: 30);

  final Map<String, _CachedFeed> _cache = {};

  /// Bumped before every load. A response whose id no longer matches lost the
  /// race to a newer selection and is dropped.
  int _loadId = 0;

  MarketBloc({
    required MarketSection section,
    JupiterTokenDataSource? source,
    WatchlistStore? watchlist,
  })  : _source = source ?? JupiterTokenDataSource(),
        _watchlist = watchlist ?? WatchlistStore.instance,
        super(MarketState(section: section, sort: _defaultSort(section))) {
    on<FetchMarketTokensEvent>(_onFetch);
    on<SelectWindowEvent>(_onSelectWindow);
    on<SelectSortEvent>(_onSelectSort);
  }

  Future<void> _onFetch(FetchMarketTokensEvent event, Emitter<MarketState> emit) async {
    final key = _cacheKey(state);
    final cached = _cache[key];
    if (!event.force && cached != null && cached.isFresh) {
      // Bumped on the cache path too. Without it, a slow request from a
      // window the user has already left still passed the staleness check
      // below: tap 5m, tap 24h before it lands, and the 5m ranking arrived
      // under the 24h chip with 24h percentages beside it.
      ++_loadId;
      emit(_ordered(state.copyWith(
        status: MarketStatus.ready,
        tokens: cached.result.tokens,
        unsorted: cached.result.tokens,
        dropped: cached.result.dropped,
        clearError: true,
      )));
      return;
    }

    final id = ++_loadId;
    emit(state.copyWith(status: MarketStatus.loading, clearError: true));

    try {
      final result = await _fetch();
      if (id != _loadId) return;
      _cache[key] = _CachedFeed(result);
      emit(_ordered(state.copyWith(
        status: MarketStatus.ready,
        tokens: result.tokens,
        unsorted: result.tokens,
        dropped: result.dropped,
      )));
    } catch (e) {
      debugLog('[Market] load failed: $e');
      if (id != _loadId) return;
      emit(state.copyWith(
        status: MarketStatus.failure,
        error: 'Could not load this list. Pull to try again.',
      ));
    }
  }

  Future<MarketFeedResult> _fetch() async {
    final section = state.section;
    if (section.isWatchlist) {
      await _watchlist.load();
      return _source.hydrate(_watchlist.mints.value);
    }
    final feed = section.feed;
    if (feed != null) {
      return MarketFeedResult(tokens: await _source.feed(feed, state.window));
    }
    return _source.shelf(section.shelf!);
  }

  void _onSelectWindow(SelectWindowEvent event, Emitter<MarketState> emit) {
    if (event.window == state.window) return;
    final next = state.copyWith(window: event.window);

    // A shelf holds every window's stats already, so the chips only change
    // which one is read. A feed is a different ranking per window, so that
    // one has to be asked for again.
    if (state.section.feed == null) {
      emit(_ordered(next));
      return;
    }
    emit(next);
    add(const FetchMarketTokensEvent());
  }

  void _onSelectSort(SelectSortEvent event, Emitter<MarketState> emit) {
    final sameKey = event.sort == state.sort;
    emit(_ordered(state.copyWith(
      sort: event.sort,
      descending: sameKey ? !state.descending : true,
    )));
  }

  /// Always sorts from the feed's own order, never from the last sort's
  /// output — which is what made Rank a one-way door.
  MarketState _ordered(MarketState next) => next.copyWith(
        tokens: sortMarketTokens(
          next.unsorted.isEmpty ? next.tokens : next.unsorted,
          sort: next.sort,
          window: next.window,
          descending: next.descending,
        ),
      );

  /// A feed and a watchlist both arrive in an order that means something —
  /// Jupiter's ranking and the user's own. A shelf does not, so it opens on
  /// the measure that means most for an asset rather than on registry order.
  static MarketSort _defaultSort(MarketSection section) =>
      section.shelf == null ? MarketSort.rank : MarketSort.marketCap;

  String _cacheKey(MarketState state) =>
      state.section.feed != null ? '${state.section.name}/${state.window.label}' : state.section.name;
}

class _CachedFeed {
  final MarketFeedResult result;
  final DateTime at;

  _CachedFeed(this.result) : at = DateTime.now();

  bool get isFresh => DateTime.now().difference(at) < MarketBloc.cacheTtl;
}
