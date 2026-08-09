import 'package:bloc/bloc.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_feed_result.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';

class MarketBloc extends Bloc<MarketEvent, MarketState> {
  final JupiterTokenDataSource _source;

  /// Long enough that flicking between tabs is free, short enough that the
  /// prices on a market screen are still prices.
  static const Duration cacheTtl = Duration(seconds: 30);

  final Map<String, _CachedFeed> _cache = {};

  /// Bumped before every load. A response whose id no longer matches lost the
  /// race to a newer selection and is dropped, so a slow trending fetch cannot
  /// land on top of the stocks shelf the user has since opened.
  int _loadId = 0;

  MarketBloc({JupiterTokenDataSource? source})
      : _source = source ?? JupiterTokenDataSource(),
        super(const MarketState()) {
    on<FetchMarketTokensEvent>(_onFetch);
    on<SelectCategoryEvent>(_onSelectCategory);
    on<SelectFeedEvent>(_onSelectFeed);
    on<SelectWindowEvent>(_onSelectWindow);
    on<SelectSortEvent>(_onSelectSort);
  }

  Future<void> _onFetch(FetchMarketTokensEvent event, Emitter<MarketState> emit) async {
    final key = _cacheKey(state);
    final cached = _cache[key];
    if (!event.force && cached != null && cached.isFresh) {
      emit(_ordered(state.copyWith(
        status: MarketStatus.ready,
        tokens: cached.result.tokens,
        dropped: cached.result.dropped,
        clearError: true,
      )));
      return;
    }

    final id = ++_loadId;
    emit(state.copyWith(status: MarketStatus.loading, clearError: true));

    try {
      final result = state.category.isFeedDriven
          ? MarketFeedResult(tokens: await _source.feed(state.feed, state.window))
          : await _source.shelf(state.category);

      if (id != _loadId) return;
      _cache[key] = _CachedFeed(result);
      emit(_ordered(state.copyWith(
        status: MarketStatus.ready,
        tokens: result.tokens,
        dropped: result.dropped,
      )));
    } catch (e) {
      debugLog('[Market] load failed: $e');
      if (id != _loadId) return;
      emit(state.copyWith(
        status: MarketStatus.failure,
        error: 'Could not load the market. Pull to try again.',
      ));
    }
  }

  void _onSelectCategory(SelectCategoryEvent event, Emitter<MarketState> emit) {
    if (event.category == state.category) return;
    // The old rows belong to the old shelf. Clearing them stops the list
    // showing stocks under a Commodities heading for the length of a fetch.
    emit(state.copyWith(
      category: event.category,
      sort: _defaultSort(event.category),
      descending: true,
      tokens: const [],
      dropped: 0,
      clearError: true,
    ));
    add(const FetchMarketTokensEvent());
  }

  void _onSelectFeed(SelectFeedEvent event, Emitter<MarketState> emit) {
    if (event.feed == state.feed) return;
    emit(state.copyWith(feed: event.feed, tokens: const [], clearError: true));
    add(const FetchMarketTokensEvent());
  }

  void _onSelectWindow(SelectWindowEvent event, Emitter<MarketState> emit) {
    if (event.window == state.window) return;
    final next = state.copyWith(window: event.window);

    // A shelf holds every window's stats already, so the chips only change
    // which one is read. A feed is a different ranking per window, so that
    // one has to be asked for again.
    if (!state.category.isFeedDriven) {
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

  MarketState _ordered(MarketState next) => next.copyWith(
        tokens: sortMarketTokens(
          next.tokens,
          sort: next.sort,
          window: next.window,
          descending: next.descending,
        ),
      );

  /// A shelf has no ranking of its own, so it opens on the measure that means
  /// most for a real-world asset rather than on registry order.
  MarketSort _defaultSort(MarketCategory category) =>
      category.isFeedDriven ? MarketSort.rank : MarketSort.marketCap;

  String _cacheKey(MarketState state) => state.category.isFeedDriven
      ? '${state.feed.path}/${state.window.label}'
      : state.category.name;
}

class _CachedFeed {
  final MarketFeedResult result;
  final DateTime at;

  _CachedFeed(this.result) : at = DateTime.now();

  bool get isFresh => DateTime.now().difference(at) < MarketBloc.cacheTtl;
}
