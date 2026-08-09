import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';

void main() {
  group('display names', () {
    test('the issuer suffix comes off, so a card reads as the company', () {
      const tesla = 'XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB';
      expect(TokenizedAssetRegistry.displayName(tesla, 'Tesla xStock'), 'Tesla');
    });

    test('every issuer this registry lists is handled', () {
      String strip(String name) => TokenizedAssetRegistry.displayName('unlisted', name);
      expect(strip('OpenAI PreStocks'), 'OpenAI');
      expect(strip('SpaceX - Backpack Securities'), 'SpaceX');
      expect(strip('iShares Silver Trust (Ondo Tokenized)'), 'iShares Silver Trust');
    });

    test('an override wins, for the tickers nobody says out loud', () {
      const spy = 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W';
      expect(TokenizedAssetRegistry.displayName(spy, 'SP500 xStock'), 'S&P 500');
    });

    test('a mint nobody has named still gets a sensible name', () {
      expect(TokenizedAssetRegistry.displayName('whatever', 'Some New Token'), 'Some New Token');
    });

    test('a name that is nothing but the suffix keeps the original', () {
      // Stripping would leave a blank card, which reads as a bug.
      expect(TokenizedAssetRegistry.displayName('whatever', 'xStock'), 'xStock');
    });
  });

  group('shelves', () {
    test('every bundled mint is on exactly one shelf', () {
      final seen = <String, MarketCategory>{};
      for (final category in MarketCategory.values) {
        for (final mint in TokenizedAssetRegistry.mintsFor(category)) {
          expect(seen.containsKey(mint), isFalse,
              reason: '$mint is on both ${seen[mint]} and $category');
          seen[mint] = category;
        }
      }
      expect(seen, isNotEmpty);
    });

    test('every bundled mint is a plausible base58 address', () {
      final base58 = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');
      for (final category in MarketCategory.values) {
        for (final mint in TokenizedAssetRegistry.mintsFor(category)) {
          expect(base58.hasMatch(mint), isTrue, reason: '$mint on $category');
        }
      }
    });

    test('a feed shelf has no bundled mints — its rows come from the API', () {
      expect(TokenizedAssetRegistry.mintsFor(MarketCategory.tokens), isEmpty);
    });

    test('categoryOf finds a mint on whichever shelf holds it', () {
      const gold = 'AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P';
      expect(TokenizedAssetRegistry.categoryOf(gold), MarketCategory.commodities);
      expect(TokenizedAssetRegistry.categoryOf('not-a-mint'), isNull);
    });
  });

  group('the RWA recheck', () {
    test('applies to tokenised assets and not to major crypto', () {
      // Wrapped BTC is not tagged rwa and never will be, so applying the
      // check there would empty the shelf.
      expect(MarketCategory.stocks.requiresRwaTag, isTrue);
      expect(MarketCategory.etfs.requiresRwaTag, isTrue);
      expect(MarketCategory.commodities.requiresRwaTag, isTrue);
      expect(MarketCategory.majorCrypto.requiresRwaTag, isFalse);
    });

    test('accepts every issuer tag the registry bundles', () {
      for (final tag in ['xstocks', 'prestocks', 'backpack', 'ondo', 'rwa']) {
        expect(TokenizedAssetRegistry.tagsSupportRwa([tag]), isTrue, reason: tag);
      }
      expect(TokenizedAssetRegistry.tagsSupportRwa(['meme', 'launchpad']), isFalse);
    });
  });
}
