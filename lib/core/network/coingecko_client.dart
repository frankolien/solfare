import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/util/app_log.dart';

/// Single shared CoinGecko HTTP client for the whole app.
///
/// Solves three problems that hit us when every screen called CoinGecko
/// directly:
///   1. Persistent on-disk cache keyed by URL — survives hot restart.
///   2. Request throttling — min gap between calls, serialised queue.
///   3. 429-friendly — serves stale cache instead of throwing.
///
/// Usage: `CoinGeckoClient.instance.getJson(url, ttl: Duration(minutes: 5))`.
class CoinGeckoClient {
  CoinGeckoClient._();
  static final CoinGeckoClient instance = CoinGeckoClient._();

  final http.Client _http = http.Client();

  // Minimum spacing between outbound requests. CoinGecko free tier tolerates
  // ~10-30 req/min — 2s gap gives us ~30/min worst case.
  static const Duration _minGap = Duration(milliseconds: 2000);

  // Serialised queue: only one request in flight at a time.
  Future<void> _queue = Future.value();
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Coalesce concurrent callers of the same URL.
  final Map<String, Future<Map<String, dynamic>?>> _inflight = {};

  /// Fetch JSON from [url]. Returns cached value when fresh, or on 429/error
  /// if any cached value exists (possibly stale). Returns null only when the
  /// request has never succeeded.
  Future<Map<String, dynamic>?> getJson(
    String url, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = await _readCache(url);
    if (cached != null && _isFresh(cached['fetchedAt'] as int, ttl)) {
      return cached['body'] as Map<String, dynamic>?;
    }

    // If someone else is already fetching this URL, wait for them.
    final existing = _inflight[url];
    if (existing != null) return existing;

    final fetch = _scheduleFetch(url, cached).whenComplete(() {
      _inflight.remove(url);
    });
    _inflight[url] = fetch;
    return fetch;
  }

  /// Same as [getJson] but returns the raw JSON list at the top level
  /// (CoinGecko's /coins/markets endpoint returns an array, not an object).
  Future<List<dynamic>?> getJsonArray(
    String url, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final body = await getJson(url, ttl: ttl);
    if (body == null) return null;
    final data = body['__array__'];
    return data is List ? data : null;
  }

  Future<Map<String, dynamic>?> _scheduleFetch(
    String url,
    Map<String, dynamic>? staleCached,
  ) async {
    final completer = Completer<Map<String, dynamic>?>();
    _queue = _queue.then((_) async {
      try {
        // Respect the inter-request gap.
        final sinceLast = DateTime.now().difference(_lastRequestAt);
        if (sinceLast < _minGap) {
          await Future.delayed(_minGap - sinceLast);
        }
        final result = await _doFetch(url, staleCached);
        _lastRequestAt = DateTime.now();
        completer.complete(result);
      } catch (e) {
        completer.complete(staleCached?['body'] as Map<String, dynamic>?);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>?> _doFetch(
    String url,
    Map<String, dynamic>? staleCached,
  ) async {
    try {
      debugLog('[CoinGecko] GET $url');
      // Hard timeout: this client serialises requests, so one hung socket
      // would stall every subsequent fetch. The catch below falls back to
      // stale cache, which is what we want when an upstream is misbehaving.
      final response = await _http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Solfare-Wallet/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final body = decoded is List
            ? <String, dynamic>{'__array__': decoded}
            : decoded as Map<String, dynamic>;
        await _writeCache(url, body);
        return body;
      }
      if (response.statusCode == 429) {
        debugLog('[CoinGecko] 429 — serving stale cache for $url');
        return staleCached?['body'] as Map<String, dynamic>?;
      }
      debugLog('[CoinGecko] HTTP ${response.statusCode} — serving stale cache for $url');
      return staleCached?['body'] as Map<String, dynamic>?;
    } catch (e) {
      debugLog('[CoinGecko] fetch error: $e — serving stale cache for $url');
      return staleCached?['body'] as Map<String, dynamic>?;
    }
  }

  bool _isFresh(int fetchedAtMs, Duration ttl) {
    final age = DateTime.now().millisecondsSinceEpoch - fetchedAtMs;
    return age < ttl.inMilliseconds;
  }

  Future<Map<String, dynamic>?> _readCache(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(url));
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String url, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(url),
        jsonEncode({
          'fetchedAt': DateTime.now().millisecondsSinceEpoch,
          'body': body,
        }),
      );
    } catch (_) {}
  }

  String _cacheKey(String url) => 'cg_cache::$url';
}
