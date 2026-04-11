import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solfare/features/market/data/model/market_token_model.dart';

abstract class MarketDataSource {
  Future<List<MarketTokenModel>> getTopTokens({int page, int perPage});
}

class MarketDataSourceImpl implements MarketDataSource {
  final String baseUrl;
  final http.Client client;

  // Cache
  List<MarketTokenModel>? _cachedTokens;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  MarketDataSourceImpl({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'https://api.coingecko.com/api/v3',
        client = client ?? http.Client();

  @override
  Future<List<MarketTokenModel>> getTopTokens({int page = 1, int perPage = 50}) async {
    // Check cache
    if (_cachedTokens != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      print('[Market] Using cached tokens (${_cachedTokens!.length} items)');
      return _cachedTokens!;
    }

    try {
      print('[Market] Fetching top tokens from CoinGecko...');
      final url = '$baseUrl/coins/markets'
          '?vs_currency=usd'
          '&order=market_cap_desc'
          '&per_page=$perPage'
          '&page=$page'
          '&sparkline=true';

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Solfare-Wallet/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final tokens = data
            .map((json) => MarketTokenModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Update cache
        _cachedTokens = tokens;
        _cacheTimestamp = DateTime.now();

        print('[Market] Fetched ${tokens.length} tokens');
        return tokens;
      } else if (response.statusCode == 429) {
        print('[Market] Rate limited (429), using cache');
        if (_cachedTokens != null) return _cachedTokens!;
        throw Exception('Rate limit exceeded');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[Market] Error: $e');
      if (_cachedTokens != null) {
        print('[Market] Returning cached data');
        return _cachedTokens!;
      }
      throw Exception('Failed to fetch market data: $e');
    }
  }
}
