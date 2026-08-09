import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/data/model/market_token_model.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

void main() {
  // Trimmed from a live /tokens/v2/toptrending/24h response.
  Map<String, dynamic> payload({
    Object? mcap = 1000944938.75,
    Object? fdv = 2140117051.59,
    Object? name = 'Pump',
    Object? organicScore = 98.03,
  }) =>
      {
        'id': 'pumpCmXqMfrsAkQ5r49WcJnRayYRqmXz6ae8H7H9Dfn',
        'name': name,
        'symbol': 'PUMP',
        'icon': 'https://ipfs.io/ipfs/bafkrei',
        'decimals': 6,
        'tokenProgram': 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
        'holderCount': 128678,
        'fdv': fdv,
        'mcap': mcap,
        'usdPrice': 0.002541364369081247,
        'liquidity': 23696465.45,
        'organicScore': organicScore,
        'isVerified': true,
        'tags': ['verified', 'defi', 'token-2022'],
        'stats5m': {'priceChange': -0.0557, 'buyVolume': 31126.36, 'sellVolume': 13110.31},
        'stats1h': {'priceChange': -0.2469, 'buyVolume': 493195.81, 'sellVolume': 436514.82},
        'stats6h': {'priceChange': 1.5226, 'buyVolume': 3481563.87, 'sellVolume': 3354372.76},
        'stats24h': {
          'priceChange': 9.6830,
          'buyVolume': 12829444.20,
          'sellVolume': 10514952.12,
          'numBuys': 90336,
          'numSells': 65826,
          'numTraders': 6046,
        },
      };

  test('the mint is the identity, and it comes with what an order needs', () {
    final token = MarketTokenModel.fromJupiter(payload());
    expect(token.id, 'pumpCmXqMfrsAkQ5r49WcJnRayYRqmXz6ae8H7H9Dfn');
    expect(token.decimals, 6);
    expect(token.tokenProgram, 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb');
  });

  test('every window is parsed from the one response', () {
    final token = MarketTokenModel.fromJupiter(payload());
    expect(token.stats.keys.toSet(), MarketWindow.values.toSet());
    expect(token.priceChange(MarketWindow.m5), closeTo(-0.0557, 0.0001));
    expect(token.priceChange(MarketWindow.h24), closeTo(9.683, 0.001));
  });

  test('volume is both sides and net is the difference', () {
    final stats = MarketTokenModel.fromJupiter(payload()).statsFor(MarketWindow.h24);
    expect(stats.volume, closeTo(23344396.32, 0.01));
    expect(stats.netVolume, closeTo(2314492.08, 0.01));
  });

  test('a market cap the API did not report stays null, not zero', () {
    final token = MarketTokenModel.fromJupiter(payload(mcap: null, fdv: null));
    expect(token.marketCap, isNull,
        reason: 'zero would claim the token is worthless rather than unmeasured');
  });

  test('fdv stands in when circulating supply is unknown', () {
    final token = MarketTokenModel.fromJupiter(payload(mcap: null));
    expect(token.marketCap, closeTo(2140117051.59, 0.01));
  });

  test('a nameless token falls back to its ticker, not to blank', () {
    expect(MarketTokenModel.fromJupiter(payload(name: '')).name, 'PUMP');
    expect(MarketTokenModel.fromJupiter(payload(name: null)).name, 'PUMP');
  });

  test('integers where the API sometimes sends doubles still parse', () {
    final token = MarketTokenModel.fromJupiter(payload(mcap: 1000, organicScore: 98));
    expect(token.marketCap, 1000.0);
    expect(token.organicScore, 98.0);
  });

  test('a missing stats block reads as no movement rather than throwing', () {
    final json = payload()..remove('stats5m');
    final token = MarketTokenModel.fromJupiter(json);
    expect(token.stats.containsKey(MarketWindow.m5), isFalse);
    expect(token.priceChange(MarketWindow.m5), 0);
  });

  test('the shelf is supplied by the caller, never read from the payload', () {
    final token = MarketTokenModel.fromJupiter(payload(), category: MarketCategory.commodities);
    expect(token.category, MarketCategory.commodities);
  });
}
