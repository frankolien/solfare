import 'dart:convert';
import 'package:http/http.dart' as http;

/// Data source for fetching cryptocurrency prices
/// Uses CoinGecko API (free, no API key required)
/// Note: Free tier has rate limits (10-50 calls/minute)
abstract class CryptoPriceDataSource {
  /// Fetch current SOL price in USD
  Future<double> getSolPrice();

  /// Fetch SOL price change percentage (24h)
  Future<double> getSolPriceChange24h();
}

class CryptoPriceDataSourceImpl implements CryptoPriceDataSource {
  final String baseUrl;
  final http.Client client;
  
  // Cache to avoid hitting rate limits
  double? _cachedPrice;
  double? _cachedPriceChange;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5); // Cache for 5 minutes

  CryptoPriceDataSourceImpl({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'https://api.coingecko.com/api/v3',
        client = client ?? http.Client();

  @override
  Future<double> getSolPrice() async {
    // Check cache first
    if (_cachedPrice != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      print('[CoinGecko] Using cached SOL price: \$${_cachedPrice!.toStringAsFixed(2)}');
      return _cachedPrice!;
    }

    try {
      print('[CoinGecko] Fetching SOL price from API...');
      final response = await client.get(
        Uri.parse('$baseUrl/simple/price?ids=solana&vs_currencies=usd'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Solfare-Wallet/1.0', // Some APIs prefer user agent
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['solana'] != null && data['solana']['usd'] != null) {
          final price = (data['solana']['usd'] as num).toDouble();
          // Update cache
          _cachedPrice = price;
          _cacheTimestamp = DateTime.now();
          print('[CoinGecko] SOL price fetched: \$${price.toStringAsFixed(2)}');
          return price;
        }
        throw Exception('Invalid price data format');
      } else if (response.statusCode == 429) {
        // Rate limit exceeded - use cached value if available
        print('[CoinGecko] Rate limit exceeded (429). Using cached price if available.');
        if (_cachedPrice != null) {
          print(' [CoinGecko] Returning cached price: \$${_cachedPrice!.toStringAsFixed(2)}');
          return _cachedPrice!;
        }
        throw Exception('Rate limit exceeded and no cached price available');
      } else {
        print('[CoinGecko] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        // Try to use cached value on error
        if (_cachedPrice != null) {
          print('[CoinGecko] Error occurred, using cached price: \$${_cachedPrice!.toStringAsFixed(2)}');
          return _cachedPrice!;
        }
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[CoinGecko] Error fetching SOL price: $e');
      // Try to use cached value on error
      if (_cachedPrice != null) {
        print('[CoinGecko] Exception occurred, using cached price: \$${_cachedPrice!.toStringAsFixed(2)}');
        return _cachedPrice!;
      }
      throw Exception('Failed to fetch SOL price: $e');
    }
  }

  @override
  Future<double> getSolPriceChange24h() async {
    // Check cache first
    if (_cachedPriceChange != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      print('CoinGecko] Using cached SOL price change: ${_cachedPriceChange!.toStringAsFixed(2)}%');
      return _cachedPriceChange!;
    }

    try {
      print('[CoinGecko] Fetching SOL price change from API...');
      final response = await client.get(
        Uri.parse('$baseUrl/simple/price?ids=solana&vs_currencies=usd&include_24hr_change=true'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Solfare-Wallet/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['solana'] != null && data['solana']['usd_24h_change'] != null) {
          final priceChange = (data['solana']['usd_24h_change'] as num).toDouble();
          // Update cache
          _cachedPriceChange = priceChange;
          _cacheTimestamp = DateTime.now();
          print('[CoinGecko] SOL price change fetched: ${priceChange.toStringAsFixed(2)}%');
          return priceChange;
        }
        throw Exception('Invalid price change data format');
      } else if (response.statusCode == 429) {
        // Rate limit exceeded - use cached value if available
        print('[CoinGecko] Rate limit exceeded (429). Using cached price change if available.');
        if (_cachedPriceChange != null) {
          print('[CoinGecko] Returning cached price change: ${_cachedPriceChange!.toStringAsFixed(2)}%');
          return _cachedPriceChange!;
        }
        throw Exception('Rate limit exceeded and no cached price change available');
      } else {
        print('[CoinGecko] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        // Try to use cached value on error
        if (_cachedPriceChange != null) {
          print('💾 [CoinGecko] Error occurred, using cached price change: ${_cachedPriceChange!.toStringAsFixed(2)}%');
          return _cachedPriceChange!;
        }
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[CoinGecko] Error fetching SOL price change: $e');
      // Try to use cached value on error
      if (_cachedPriceChange != null) {
        print('[CoinGecko] Exception occurred, using cached price change: ${_cachedPriceChange!.toStringAsFixed(2)}%');
        return _cachedPriceChange!;
      }
      throw Exception('Failed to fetch SOL price change: $e');
    }
  }
}
