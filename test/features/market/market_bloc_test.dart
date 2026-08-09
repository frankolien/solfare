import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
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
  }) =>
      {
        'id': mint ?? symbol.padRight(32, 'x'),
        'name': symbol,
        'symbol': symbol,
        'icon': '',
        'decimals': 6,
        'usdPrice': 1.0,
        'isVerified': true,
        'tags': ['rwa', 'stocks'],
        'stats24h': {'priceChange': h24, 'buyVolume': volume, 'sellVolume': 0.0},
        'stats1h': {'priceChange': h1, 'buyVolume': volume, 'sellVolume': 0.0},
      };

  late List<String> requested;

  MarketBloc blocReturning(List<Map<String, dynamic>> rows) {
    requested = [];
    return MarketBloc(
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

  test('the opening list keeps the feed ranking rather than a column of ours', () async {
    final bloc = blocReturning([row('C'), row('A'), row('B')]);
    expect(bloc.state.sort, MarketSort.rank);
    bloc.add(const FetchMarketTokensEvent());
    final state = await settle(bloc);
    expect(state.tokens.map((t) => t.symbol).toList(), ['C', 'A', 'B']);
    await bloc.close();
  });

  test('a shelf opens on market cap, since it has no ranking of its own', () async {
    final bloc = blocReturning([row('A', mint: shelf.first)]);
    bloc.add(const SelectCategoryEvent(MarketCategory.stocks));
    await settle(bloc);
    expect(bloc.state.sort, MarketSort.marketCap);
    await bloc.close();
  });

  test('the old rows go when the shelf changes', () async {
    final bloc = blocReturning([row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);

    final cleared = bloc.stream.firstWhere((s) => s.category == MarketCategory.stocks);
    bloc.add(const SelectCategoryEvent(MarketCategory.stocks));
    expect((await cleared).tokens, isEmpty,
        reason: 'tokens under a Stocks heading for the length of a fetch is a lie');
    await bloc.close();
  });

  test('changing the window on a shelf re-reads what is held, it does not refetch', () async {
    final bloc = blocReturning([
      row('A', mint: shelf[0], h24: 1, h1: 9),
      row('B', mint: shelf[1], h24: 5, h1: 2),
    ]);
    bloc.add(const SelectCategoryEvent(MarketCategory.stocks));
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
    final bloc = blocReturning([row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);

    bloc.add(const SelectWindowEvent(MarketWindow.h6));
    await settle(bloc);
    expect(requested.last, contains('/toptrending/6h'));
    await bloc.close();
  });

  test('tapping the active column flips it, a different column starts descending', () async {
    final bloc = blocReturning([row('A', h24: 1, volume: 9), row('B', h24: 5, volume: 1)]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);

    bloc.add(const SelectSortEvent(MarketSort.priceChange));
    await bloc.stream.firstWhere((s) => s.sort == MarketSort.priceChange);
    expect(bloc.state.descending, isTrue);
    expect(bloc.state.tokens.first.symbol, 'B');

    bloc.add(const SelectSortEvent(MarketSort.priceChange));
    await bloc.stream.firstWhere((s) => !s.descending);
    expect(bloc.state.tokens.first.symbol, 'A', reason: 'flipping change is the losers view');

    bloc.add(const SelectSortEvent(MarketSort.volume));
    await bloc.stream.firstWhere((s) => s.sort == MarketSort.volume);
    expect(bloc.state.descending, isTrue);
    await bloc.close();
  });

  test('a second visit to a category is served from cache', () async {
    final bloc = blocReturning([row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    final callsAfterFirst = requested.length;

    bloc.add(const SelectCategoryEvent(MarketCategory.stocks));
    await settle(bloc);

    // A cache hit never reaches the loading state at all, which is the whole
    // point — so this waits on the rows, not on a load.
    bloc.add(const SelectCategoryEvent(MarketCategory.tokens));
    await bloc.stream.firstWhere(
      (s) => s.category == MarketCategory.tokens && s.tokens.isNotEmpty,
    );

    expect(requested.length, callsAfterFirst + 1, reason: 'only the stocks shelf was new');
    await bloc.close();
  });

  test('pull to refresh goes past the cache', () async {
    final bloc = blocReturning([row('A')]);
    bloc.add(const FetchMarketTokensEvent());
    await settle(bloc);
    final callsAfterFirst = requested.length;

    bloc.add(const FetchMarketTokensEvent(force: true));
    await settle(bloc);
    expect(requested.length, callsAfterFirst + 1);
    await bloc.close();
  });

  test('a failed load says so rather than showing an empty market', () async {
    final bloc = MarketBloc(
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
