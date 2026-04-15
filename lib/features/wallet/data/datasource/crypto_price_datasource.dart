import 'package:solfare/core/network/coingecko_client.dart';

/// Thin wrapper over [CoinGeckoClient] for SOL price + 24h change.
/// All caching/throttling/fallback logic lives in the shared client.
abstract class CryptoPriceDataSource {
  Future<double> getSolPrice();
  Future<double> getSolPriceChange24h();
}

class CryptoPriceDataSourceImpl implements CryptoPriceDataSource {
  static const _url =
      'https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd&include_24hr_change=true';

  CoinGeckoClient get _client => CoinGeckoClient.instance;

  Future<Map<String, dynamic>?> _fetchSolData() =>
      _client.getJson(_url, ttl: const Duration(minutes: 5));

  @override
  Future<double> getSolPrice() async {
    final body = await _fetchSolData();
    final sol = body?['solana'] as Map<String, dynamic>?;
    final price = (sol?['usd'] as num?)?.toDouble();
    if (price == null) throw Exception('No SOL price available');
    return price;
  }

  @override
  Future<double> getSolPriceChange24h() async {
    final body = await _fetchSolData();
    final sol = body?['solana'] as Map<String, dynamic>?;
    return (sol?['usd_24h_change'] as num?)?.toDouble() ?? 0;
  }
}
