import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

void main() {
  MarketToken token(
    String symbol, {
    double? marketCap,
    double? liquidity,
    int? holders,
    double? organicScore,
    double change24h = 0,
    double volume24h = 0,
    double change1h = 0,
  }) =>
      MarketToken(
        id: symbol,
        name: symbol,
        symbol: symbol,
        imageUrl: '',
        currentPrice: 1,
        marketCap: marketCap,
        liquidity: liquidity,
        holderCount: holders,
        organicScore: organicScore,
        stats: {
          MarketWindow.h24: MarketStats(priceChange: change24h, buyVolume: volume24h),
          MarketWindow.h1: MarketStats(priceChange: change1h),
        },
      );

  List<String> symbols(List<MarketToken> tokens) => tokens.map((t) => t.symbol).toList();

  test('the feed ranking survives an unstable sort', () {
    final feed = [for (var i = 0; i < 12; i++) token('T$i')];
    final ordered = sortMarketTokens(feed, sort: MarketSort.rank, window: MarketWindow.h24);
    expect(symbols(ordered), symbols(feed));
  });

  test('reversing rank walks the feed backwards', () {
    final feed = [token('A'), token('B'), token('C')];
    final ordered = sortMarketTokens(
      feed,
      sort: MarketSort.rank,
      window: MarketWindow.h24,
      descending: false,
    );
    expect(symbols(ordered), ['C', 'B', 'A']);
  });

  test('the window decides what change means', () {
    final tokens = [
      token('A', change24h: 1, change1h: 90),
      token('B', change24h: 50, change1h: 2),
    ];
    expect(
      symbols(sortMarketTokens(tokens, sort: MarketSort.priceChange, window: MarketWindow.h24)),
      ['B', 'A'],
    );
    expect(
      symbols(sortMarketTokens(tokens, sort: MarketSort.priceChange, window: MarketWindow.h1)),
      ['A', 'B'],
    );
  });

  test('flipping price change is the losers view', () {
    final tokens = [token('UP', change24h: 12), token('DOWN', change24h: -30)];
    final losers = sortMarketTokens(
      tokens,
      sort: MarketSort.priceChange,
      window: MarketWindow.h24,
      descending: false,
    );
    expect(symbols(losers).first, 'DOWN');
  });

  test('an unreported value sorts last whichever way the column points', () {
    final tokens = [
      token('KNOWN_SMALL', marketCap: 10),
      token('UNKNOWN'),
      token('KNOWN_BIG', marketCap: 1000),
    ];
    expect(
      symbols(sortMarketTokens(tokens, sort: MarketSort.marketCap, window: MarketWindow.h24)),
      ['KNOWN_BIG', 'KNOWN_SMALL', 'UNKNOWN'],
    );
    expect(
      symbols(sortMarketTokens(
        tokens,
        sort: MarketSort.marketCap,
        window: MarketWindow.h24,
        descending: false,
      )),
      ['KNOWN_SMALL', 'KNOWN_BIG', 'UNKNOWN'],
      reason: 'an unmeasured market cap is not the smallest one',
    );
  });

  test('a window with no stats block is unmeasured, not zero', () {
    final tokens = [
      token('MEASURED', volume24h: 5),
      MarketToken(id: 'BARE', name: 'BARE', symbol: 'BARE', imageUrl: '', currentPrice: 1),
    ];
    final ordered = sortMarketTokens(
      tokens,
      sort: MarketSort.volume,
      window: MarketWindow.h24,
      descending: false,
    );
    expect(symbols(ordered), ['MEASURED', 'BARE']);
  });

  test('holders and organic score order the way the numbers read', () {
    final tokens = [
      token('LOW', holders: 10, organicScore: 5),
      token('HIGH', holders: 900, organicScore: 95),
    ];
    expect(
      symbols(sortMarketTokens(tokens, sort: MarketSort.holders, window: MarketWindow.h24)).first,
      'HIGH',
    );
    expect(
      symbols(sortMarketTokens(tokens, sort: MarketSort.organicScore, window: MarketWindow.h24))
          .first,
      'HIGH',
    );
  });

  test('sorting does not mutate the list it was handed', () {
    final feed = [token('A', marketCap: 1), token('B', marketCap: 9)];
    sortMarketTokens(feed, sort: MarketSort.marketCap, window: MarketWindow.h24);
    expect(symbols(feed), ['A', 'B']);
  });
}
