import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/features/market/data/model/market_token_model.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_feed_result.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

/// Reads the market from Jupiter's token API.
class JupiterTokenDataSource {
  static const _base = 'https://lite-api.jup.ag/tokens/v2';

  // The search endpoint's documented ceiling on comma-separated mints.
  static const _searchChunk = 100;

  final http.Client client;

  JupiterTokenDataSource({http.Client? client}) : client = client ?? http.Client();

  /// One of Jupiter's live orderings, e.g. `/toptrending/24h`.
  Future<List<MarketTokenModel>> feed(
    MarketFeed feed,
    MarketWindow window, {
    int limit = 100,
  }) async {
    final json = await _getArray('$_base/${feed.path}/${window.label}?limit=$limit');
    return [
      for (final row in json.whereType<Map<String, dynamic>>())
        MarketTokenModel.fromJupiter(row),
    ];
  }

  /// Hydrates a registry shelf.
  Future<MarketFeedResult> shelf(MarketCategory category) =>
      _hydrate(TokenizedAssetRegistry.mintsFor(category), category: category);

  /// Hydrates an arbitrary set of mints — the watchlist, mostly.
  Future<MarketFeedResult> hydrate(List<String> mints) =>
      _hydrate(mints, category: null);

  Future<MarketFeedResult> _hydrate(
    List<String> mints, {
    required MarketCategory? category,
  }) async {
    final tokens = <MarketTokenModel>[];
    var dropped = 0;

    for (var i = 0; i < mints.length; i += _searchChunk) {
      final chunk = mints.sublist(i, (i + _searchChunk).clamp(0, mints.length));
      final json = await _getArray('$_base/search?query=${chunk.join(',')}');
      final byMint = {
        for (final row in json.whereType<Map<String, dynamic>>())
          if (row['id'] case final String mint) mint: row,
      };

      for (final mint in chunk) {
        final row = byMint[mint];
        if (row == null || (category != null && !_stillListable(row, category))) {
          dropped++;
          continue;
        }
        tokens.add(MarketTokenModel.fromJupiter(
          row,
          category: category ??
              TokenizedAssetRegistry.categoryOf(mint) ??
              MarketCategory.tokens,
        ));
      }
    }

    return MarketFeedResult(tokens: tokens, dropped: dropped);
  }

  /// Free-text search across every mint Jupiter indexes, plus mint addresses
  /// pasted whole.
  Future<List<MarketTokenModel>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final json = await _getArray('$_base/search?query=${Uri.encodeComponent(trimmed)}');
    return [
      for (final row in json.whereType<Map<String, dynamic>>())
        MarketTokenModel.fromJupiter(
          row,
          category: TokenizedAssetRegistry.categoryOf(row['id'] as String? ?? '') ??
              MarketCategory.tokens,
        ),
    ];
  }

  bool _stillListable(Map<String, dynamic> row, MarketCategory category) {
    if (row['isVerified'] != true) return false;
    if (category.requiresRwaTag &&
        !TokenizedAssetRegistry.tagsSupportRwa(MarketTokenModel.tagsOf(row))) {
      return false;
    }
    final price = (row['usdPrice'] as num?)?.toDouble();
    if (price == null || price <= 0) return false;
    // No liquidity means no route.
    final liquidity = (row['liquidity'] as num?)?.toDouble();
    return liquidity != null && liquidity > 0;
  }

  Future<List<dynamic>> _getArray(String url) async {
    final response = await HttpRetry.send(
      () => client.get(Uri.parse(url), headers: const {'Accept': 'application/json'}),
    );
    if (response.statusCode != 200) {
      throw Exception('Jupiter token API ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Jupiter token API returned ${decoded.runtimeType}');
    }
    return decoded;
  }
}
