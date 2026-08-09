import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/data/watchlist_store.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';

void main() {
  final shelf = TokenizedAssetRegistry.mintsFor(MarketCategory.stocks);

  Map<String, dynamic> row(
    String symbol, {
    String? mint,
    double h24 = 0,
    double h1 = 0,
    double volume = 0,
    double? mcap,
  }) =>
      {
        'id': mint ?? symbol.padRight(32, 'x'),
        'name': symbol,
        'symbol': symbol,
        'icon': '',
        'decimals': 6,
        'usdPrice': 1.0,
        'liquidity': 5000.0,
        'mcap': mcap,
        'isVerified': true,
        'tags': ['rwa', 'stocks'],
        'stats24h': {'priceChange': h24, 'buyVolume': volume, 'sellVolume': 0.0},
        'stats1h': {'priceChange': h1, 'buyVolume': volume, 'sellVolume': 0.0},
      };

  late List<String> requested;

  MarketBloc blocFor(MarketSection section, List<Map<String, dynamic>> rows) {
    requested = [];
    return MarketBloc(
      section: section,
      source: JupiterTokenDataSource(
        client: MockClient((request) async {
          requested.add(request.url.path);
          return http.Response(jsonEncode(rows), 200);
        }),
      ),
    );
  }

  /// Waits for a load to run, not merely for the state to look ready — a
  /// selection change emits before its fetch starts.
  Future<MarketState> settle(MarketBloc bloc) async {
    await bloc.stream.firstWhere((s) => s.status == MarketStatus.loading);
    return bloc.stream.firstWhere((s) => s.status != MarketStatus.loading);
  }

  test('a feed keeps its own ranking rather than a column of ours', () async {
    final bloc = blocFor(MarketSection.trending, [row('C'), row('A'), row('B')]);
    expect(bloc.state.sort, MarketSort.rank);
    bloc.add(const FetchMarketTokensEvent());
    final state = await settle(bloc);
    expect(state.tokens.map((t) => t.symbol).toList(), ['C', 'A', 'B']);
    await bloc.close();
  });

  test('a shelf opens on market cap, since it has no ranking of its own', () async {
    final bloc = blocFor(MarketSection.stocks, [row('A', mint: shelf.first)]);
    expect(bloc.state.sort, MarketSort.marketCap);
    await bloc.close();
  });

  test('changing the window on a shelf re-reads what is held, it does not refetch', () async {
    final bloc = blocFor(MarketSection.stocks, [
      row('A', mint: shelf[0], h24: 1, h1: 9),
      row('B', mint: shelf[1], h24: 5, h1: 2),
    ]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    final callsAfterLoad = requested.length;

    bloc.add(const SelectSortEvent(MarketSort.priceChange));
    bloc.add(const SelectWindowEvent(MarketWindow.h1));
    await bloc.stream.firstWhere((s) => s.window == MarketWindow.h1);

    expect(requested.length, callsAfterLoad, reason: 'every window came in the first response');
    expect(bloc.state.tokens.first.symbol, 'A', reason: 'A leads over 1h, B over 24h');
    await bloc.close();
  });

  test('changing the window on a feed asks for that window, since it is a different ranking',
      () async {
    final bloc = blocFor(MarketSection.trending, [row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);

    bloc.add(const SelectWindowEvent(MarketWindow.h6));
    await settle(bloc);
    expect(requested.last, contains('/toptrending/6h'));
    await bloc.close();
  });

  test('most traded reads a different feed to trending', () async {
    final bloc = blocFor(MarketSection.mostTraded, [row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    expect(requested.last, contains('/toptraded/24h'));
    await bloc.close();
  });

  test('tapping the active column flips it, a different column starts descending', () async {
    final bloc = blocFor(MarketSection.trending, [
      row('A', h24: 1, volume: 9, mcap: 10),
      row('B', h24: 5, volume: 1, mcap: 90),
    ]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);

    bloc.add(const SelectSortEvent(MarketSort.priceChange));
    await bloc.stream.firstWhere((s) => s.sort == MarketSort.priceChange);
    expect(bloc.state.descending, isTrue);
    expect(bloc.state.tokens.first.symbol, 'B');

    bloc.add(const SelectSortEvent(MarketSort.priceChange));
    await bloc.stream.firstWhere((s) => !s.descending);
    expect(bloc.state.tokens.first.symbol, 'A', reason: 'flipping change is the losers view');

    bloc.add(const SelectSortEvent(MarketSort.marketCap));
    await bloc.stream.firstWhere((s) => s.sort == MarketSort.marketCap);
    expect(bloc.state.descending, isTrue);
    expect(bloc.state.tokens.first.symbol, 'B');
    await bloc.close();
  });

  test('a repeat load of the same window is served from cache', () async {
    final bloc = blocFor(MarketSection.trending, [row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    final callsAfterFirst = requested.length;

    // A cache hit never reaches the loading state, and re-emitting an equal
    // state is a no-op, so there is nothing to wait on but the event loop.
    bloc.add(const FetchMarketTokensEvent());
    await pumpEventQueue();
    expect(requested.length, callsAfterFirst);
    await bloc.close();
  });

  test('pull to refresh goes past the cache', () async {
    final bloc = blocFor(MarketSection.trending, [row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    final callsAfterFirst = requested.length;

    bloc.add(const FetchMarketTokensEvent(force: true));
    await settle(bloc);
    expect(requested.length, callsAfterFirst + 1);
    await bloc.close();
  });

  test('the watchlist list shows the starred mints, in the order they were starred', () async {
    final watchlist = WatchlistStore.instance..resetForTest();
    await watchlist.add(shelf[1]);
    await watchlist.add(shelf[0]);

    final bloc = MarketBloc(
      section: MarketSection.watchlist,
      watchlist: watchlist,
      source: JupiterTokenDataSource(
        client: MockClient((_) async => http.Response(
              jsonEncode([row('SECOND', mint: shelf[0]), row('FIRST', mint: shelf[1])]),
              200,
            )),
      ),
    );
    bloc.add(const FetchMarketTokensEvent());
    final state = await settle(bloc);
    expect(state.tokens.map((t) => t.symbol).toList(), ['FIRST', 'SECOND']);
    await bloc.close();
    watchlist.resetForTest();
  });

  test('a failed load says so rather than showing an empty market', () async {
    final bloc = MarketBloc(
      section: MarketSection.trending,
      source: JupiterTokenDataSource(
        client: MockClient((_) async => http.Response('nope', 500)),
      ),
    );
    bloc.add(const FetchMarketTokensEvent());
    final state = await bloc.stream.firstWhere((s) => s.status == MarketStatus.failure);
    expect(state.error, isNotNull);
    expect(state.tokens, isEmpty);
    await bloc.close();
  });
}
