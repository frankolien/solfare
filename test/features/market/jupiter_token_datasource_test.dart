import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

void main() {
  final shelf = TokenizedAssetRegistry.mintsFor(MarketCategory.commodities);
  final gold = shelf.first;

  Map<String, dynamic> row(
    String mint, {
    bool verified = true,
    List<String> tags = const ['rwa', 'commodities'],
    double? price = 4325.17,
    double? liquidity = 491604,
  }) =>
      {
        'id': mint,
        'name': 'Tether Gold',
        'symbol': 'XAUt0',
        'icon': '',
        'decimals': 6,
        'tokenProgram': 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
        'usdPrice': price,
        'liquidity': liquidity,
        'isVerified': verified,
        'tags': tags,
        'stats24h': {'priceChange': -0.01, 'buyVolume': 100.0, 'sellVolume': 50.0},
      };

  JupiterTokenDataSource sourceReturning(List<Map<String, dynamic>> rows) {
    return JupiterTokenDataSource(
      client: MockClient((request) async {
        lastUri = request.url;
        return http.Response(jsonEncode(rows), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
  }

  group('shelf hydration', () {
    test('a mint the API stopped serving is dropped and counted', () async {
      final source = sourceReturning([row(gold)]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens.length, 1);
      expect(result.dropped, shelf.length - 1);
    });

    test('a mint that lost its verification is dropped', () async {
      final source = sourceReturning([row(gold, verified: false)]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens, isEmpty);
      expect(result.dropped, shelf.length);
    });

    test('a mint that no longer reads as a real-world asset is dropped', () async {
      final source = sourceReturning([row(gold, tags: ['meme', 'launchpad'])]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens, isEmpty,
          reason: 'a shelf that is short is honest, a shelf that is wrong is not');
    });

    test('a mint nobody is quoting is dropped, price or not', () async {
      final source = sourceReturning([row(gold, liquidity: 0)]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens, isEmpty,
          reason: 'no liquidity means no route, so the card could not be bought');
    });

    test('a mint with no price is dropped rather than shown at zero', () async {
      final source = sourceReturning([row(gold, price: null)]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens, isEmpty);
    });

    test('what survives is shelved where the registry said, not where the tags did', () async {
      final source = sourceReturning([row(gold, tags: ['stocks', 'rwa'])]);
      final result = await source.shelf(MarketCategory.commodities);
      expect(result.tokens.single.category, MarketCategory.commodities);
    });

    test('the response is matched by mint, not by position', () async {
      // The API is under no obligation to answer in the order it was asked.
      final stocks = TokenizedAssetRegistry.mintsFor(MarketCategory.stocks);
      final source = sourceReturning([
        row(stocks[2], tags: const ['rwa']),
        row(stocks[0], tags: const ['rwa']),
      ]);
      final result = await source.shelf(MarketCategory.stocks);
      expect(result.tokens.map((t) => t.id).toList(), [stocks[0], stocks[2]],
          reason: 'the registry decides the order the shelf is built in');
    });
  });

  group('feeds', () {
    test('the feed and window pick the path', () async {
      final source = sourceReturning([row(gold)]);
      await source.feed(MarketFeed.organic, MarketWindow.h6);
      expect(lastUri.toString(), contains('/toporganicscore/6h'));
    });

    test('feed rows are tokens, whatever they are tagged', () async {
      final source = sourceReturning([row(gold, tags: const ['commodities'])]);
      final tokens = await source.feed(MarketFeed.trending, MarketWindow.h24);
      expect(tokens.single.category, MarketCategory.tokens);
    });
  });

  group('search', () {
    test('an empty query never reaches the network', () async {
      final source = JupiterTokenDataSource(
        client: MockClient((_) async => throw StateError('should not be called')),
      );
      expect(await source.search('   '), isEmpty);
    });

    test('a hit that is on a shelf comes back shelved', () async {
      final source = sourceReturning([row(gold)]);
      final results = await source.search('gold');
      expect(results.single.category, MarketCategory.commodities);
    });
  });
}

/// Last URL the mock client was asked for.
Uri lastUri = Uri();
