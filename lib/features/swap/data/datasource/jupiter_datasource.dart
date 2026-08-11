import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solfare/core/constant/api_keys.dart';
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/core/util/json.dart';
import 'package:solfare/features/swap/domain/swap_executor.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

class JupiterDataSource {
  static const _baseUrl = 'https://api.jup.ag/swap/v2';
  static String get _apiKey => ApiKeys.jupiter;

  final http.Client client;

  JupiterDataSource({http.Client? client}) : client = client ?? http.Client();

  /// Returns a curated list of popular Solana tokens for swapping.
  List<SwapToken> getTokenList() {
    return _popularTokens;
  }

  /// Get an order from Jupiter v2 (/order endpoint).
  Future<Map<String, dynamic>> getQuote({
    required String inputMint,
    required String outputMint,
    required int amount,
    int slippageBps = 50,
    String? taker,
  }) async {
    final url = '$_baseUrl/order'
        '?inputMint=$inputMint'
        '&outputMint=$outputMint'
        '&amount=$amount'
        '&slippageBps=$slippageBps'
        '${taker != null ? '&taker=$taker' : ''}';

    final response = await HttpRetry.send(
      () => client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'x-api-key': _apiKey,
        },
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Jupiter answers an unroutable pair with HTTP 200 and an error in the
      // body — "Swapping of jlWSOL is not supported" — exactly as execute()
      // reports a reverted swap. Reading only the status code threw that
      // sentence away and left the screen saying "Failed to get quote", which
      // reads as the app being broken rather than the token being unsupported.
      final reason = json.stringAt('error');
      if (reason != null && reason.isNotEmpty) {
        throw SwapUnavailableException(reason);
      }
      return json;
    }
    throw SwapUnavailableException(_reasonFrom(response.body) ??
        'The route service returned ${response.statusCode}.');
  }

  /// Jupiter's own words, when it gave any.
  static String? _reasonFrom(String body) {
    try {
      return asJsonMap(jsonDecode(body))?.stringAt('error');
    } catch (_) {
      return null;
    }
  }

  /// Hand the signed order back to Jupiter, which broadcasts it and polls for
  /// landing on its own infrastructure.
  Future<Map<String, dynamic>> execute({
    required String signedTransaction,
    required String requestId,
  }) async {
    final response = await HttpRetry.send(
      () => client.post(
        Uri.parse('$_baseUrl/execute'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'signedTransaction': signedTransaction,
          'requestId': requestId,
        }),
      ),
    );

    // Jupiter reports a landed-but-reverted swap as HTTP 200 with status
    // "Failed", so the body is parsed either way.
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || data['status'] != null || data['error'] != null) {
        return data;
      }
    } catch (_) {
      // Fall through to the status-code error below.
    }
    throw Exception('Swap execute failed: HTTP ${response.statusCode}');
  }

  // Top Solana tokens with correct mint addresses and decimals
  static const _cg = 'https://coin-images.coingecko.com/coins/images';
  static const List<SwapToken> _popularTokens = [
    SwapToken.sol,
    SwapToken.usdc,
    SwapToken(
      mint: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      logoUrl: '$_cg/325/large/Tether.png?1696501661',
    ),
    SwapToken(
      mint: 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN',
      symbol: 'JUP',
      name: 'Jupiter',
      decimals: 6,
      logoUrl: '$_cg/34188/large/jup.png?1704266489',
    ),
    SwapToken(
      mint: 'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So',
      symbol: 'mSOL',
      name: 'Marinade Staked SOL',
      decimals: 9,
      logoUrl: '$_cg/18867/large/c1.png?1750668234',
    ),
    SwapToken(
      mint: '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs',
      symbol: 'WETH',
      name: 'Wrapped Ether',
      decimals: 8,
      logoUrl: '$_cg/2518/large/weth.png?1696506297',
    ),
    SwapToken(
      mint: 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263',
      symbol: 'BONK',
      name: 'Bonk',
      decimals: 5,
      logoUrl: '$_cg/28600/large/bonk.png?1696527587',
    ),
    SwapToken(
      mint: 'EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm',
      symbol: 'WIF',
      name: 'dogwifhat',
      decimals: 6,
      logoUrl: '$_cg/33566/large/dogwifhat.jpg?1702499428',
    ),
    SwapToken(
      mint: '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R',
      symbol: 'RAY',
      name: 'Raydium',
      decimals: 6,
      logoUrl: '$_cg/13928/large/PSigc4ie_400x400.jpg?1696513668',
    ),
    SwapToken(
      mint: 'jtojtomepa8beP8AuQc6eXt5FriJwfFMwQx2v2f9mCL',
      symbol: 'JTO',
      name: 'Jito',
      decimals: 9,
      logoUrl: '$_cg/33228/large/jto.png?1701137022',
    ),
    SwapToken(
      mint: 'HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3',
      symbol: 'PYTH',
      name: 'Pyth Network',
      decimals: 6,
      logoUrl: '$_cg/31924/large/pyth.png?1701245725',
    ),
  ];
}
