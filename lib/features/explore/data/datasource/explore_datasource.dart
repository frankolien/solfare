import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solfare/features/explore/data/model/crypto_news_model.dart';
import 'package:solfare/features/explore/domain/entities/dapp_item.dart';

abstract class ExploreDataSource {
  Future<List<CryptoNewsModel>> fetchNews();
  List<DappItem> getDapps({String? category});
}

class ExploreDataSourceImpl implements ExploreDataSource {
  final http.Client client;

  // Cache
  List<CryptoNewsModel>? _cachedNews;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  ExploreDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<List<CryptoNewsModel>> fetchNews() async {
    // Check cache
    if (_cachedNews != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedNews!;
    }

    try {
      // CryptoPanic free API — filter by SOL/Solana
      final url = Uri.parse(
        'https://cryptopanic.com/api/free/v1/posts/'
        '?auth_token=demo'
        '&currencies=SOL'
        '&kind=news'
        '&public=true',
      );

      final response = await client.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Solfare-Wallet/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List?) ?? [];
        final news = results
            .map((json) => CryptoNewsModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _cachedNews = news;
        _cacheTimestamp = DateTime.now();
        return news;
      } else if (response.statusCode == 429) {
        if (_cachedNews != null) return _cachedNews!;
        throw Exception('Rate limit exceeded');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (_cachedNews != null) return _cachedNews!;
      throw Exception('Failed to fetch news: $e');
    }
  }

  @override
  List<DappItem> getDapps({String? category}) {
    final dapps = _allDapps;
    if (category == null || category == 'Featured') return dapps;
    return dapps.where((d) => d.category == category).toList();
  }

  // Real CoinGecko image URLs fetched from their API
  static const List<DappItem> _allDapps = [
    // Featured
    DappItem(
      name: 'Jupiter',
      description: 'The best swap aggregator on Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/34188/large/jup.png?1704266489',
      url: 'https://jup.ag',
      category: 'Featured',
    ),
    DappItem(
      name: 'Raydium',
      description: 'Leading AMM built on Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/13928/large/PSigc4ie_400x400.jpg?1696513668',
      url: 'https://raydium.io',
      category: 'Featured',
    ),
    DappItem(
      name: 'Tensor',
      description: 'The fastest NFT marketplace on Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/35972/large/tnsr.png?1712687367',
      url: 'https://www.tensor.trade',
      category: 'Featured',
    ),
    DappItem(
      name: 'Marinade',
      description: 'Liquid staking for Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/18867/large/c1.png?1750668234',
      url: 'https://marinade.finance',
      category: 'Featured',
    ),
    DappItem(
      name: 'Magic Eden',
      description: 'The #1 community-centric NFT marketplace.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/39850/large/_ME_Profile_Dark_2x.png?1734013082',
      url: 'https://magiceden.io',
      category: 'Featured',
    ),

    // Earn
    DappItem(
      name: 'Marinade',
      description: 'Liquid staking for Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/18867/large/c1.png?1750668234',
      url: 'https://marinade.finance',
      category: 'Earn',
    ),
    DappItem(
      name: 'Kamino',
      description: 'Automated liquidity on Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/35801/large/Kamino_200x200.png?1767944671',
      url: 'https://app.kamino.finance',
      category: 'Earn',
    ),
    DappItem(
      name: 'Drift',
      description: 'Decentralized perpetual exchange.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/37509/large/DRIFT.png?1715842607',
      url: 'https://www.drift.trade',
      category: 'Earn',
    ),

    // Ecosystem
    DappItem(
      name: 'Helium',
      description: 'The People\'s Network — decentralized wireless.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/4284/large/helium_logo_use.png?1748092589',
      url: 'https://www.helium.com',
      category: 'Ecosystem',
    ),
    DappItem(
      name: 'Hivemapper',
      description: 'Map the World. Do It Together.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/28388/large/honey.png?1696527388',
      url: 'https://hivemapper.com',
      category: 'Ecosystem',
    ),
    DappItem(
      name: 'Arcium',
      description: 'Encrypt Everything, Compute Anything.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/54948/large/arcium-logo.jpg?1742642420',
      url: 'https://arcium.com',
      category: 'Ecosystem',
    ),

    // Memes
    DappItem(
      name: 'pump.fun',
      description: 'Launch your own memecoin.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/67164/large/pump.jpg?1751949376',
      url: 'https://pump.fun',
      category: 'Memes',
    ),
    DappItem(
      name: 'Birdeye',
      description: 'On-chain data analytics for Solana.',
      iconUrl: 'https://coin-images.coingecko.com/coins/images/28388/large/honey.png?1696527388',
      url: 'https://birdeye.so',
      category: 'Memes',
    ),
  ];
}
