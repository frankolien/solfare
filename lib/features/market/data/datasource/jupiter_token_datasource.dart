import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/features/market/data/model/market_token_model.dart';
import 'package:solfare/features/market/data/registry/tokenized_asset_registry.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_feed_result.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

/// Reads the market from Jupiter's token API.
///
/// Every row it returns carries a mint, its decimals and its token program,
/// which is what separates a list you can look at from a list you can buy
/// from.
class JupiterTokenDataSource {
  static const _base = 'https://lite-api.jup.ag/tokens/v2';

  /// The search endpoint's documented ceiling on comma-separated mints.
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
  ///
  /// Returns what came back and what did not: a mint the API no longer serves,
  /// or no longer tags as a real-world asset, is dropped here rather than
  /// shown under a heading it has stopped belonging to. The caller is told how
  /// many so the shelf can say so instead of quietly looking short.
  Future<MarketFeedResult> shelf(MarketCategory category) async {
    final mints = TokenizedAssetRegistry.mintsFor(category);
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
        if (row == null || !_stillAnAsset(row)) {
          dropped++;
          continue;
        }
        tokens.add(MarketTokenModel.fromJupiter(row, category: category));
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

  bool _stillAnAsset(Map<String, dynamic> row) {
    if (row['isVerified'] != true) return false;
    if (!TokenizedAssetRegistry.tagsSupportRwa(MarketTokenModel.tagsOf(row))) return false;
    final price = (row['usdPrice'] as num?)?.toDouble();
    return price != null && price > 0;
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
