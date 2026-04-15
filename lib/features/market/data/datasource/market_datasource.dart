import 'package:solfare/core/network/coingecko_client.dart';
import 'package:solfare/features/market/data/model/market_token_model.dart';

abstract class MarketDataSource {
  Future<List<MarketTokenModel>> getTopTokens({int page, int perPage});
}

class MarketDataSourceImpl implements MarketDataSource {
  CoinGeckoClient get _client => CoinGeckoClient.instance;

  @override
  Future<List<MarketTokenModel>> getTopTokens({int page = 1, int perPage = 50}) async {
    final url = 'https://api.coingecko.com/api/v3/coins/markets'
        '?vs_currency=usd'
        '&order=market_cap_desc'
        '&per_page=$perPage'
        '&page=$page'
        '&sparkline=true';

    final data = await _client.getJsonArray(url, ttl: const Duration(minutes: 5));
    if (data == null) {
      throw Exception('Failed to fetch market data (no cache available)');
    }
    return data
        .map((json) => MarketTokenModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
