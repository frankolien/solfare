import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/util/app_log.dart';

/// The last balance and price we knew for one wallet.
///
/// See docs/design/instant-first-paint.md.
class PortfolioSnapshot {
  final int lamports;
  final double priceUsd;
  final double priceChange24h;
  final DateTime at;

  const PortfolioSnapshot({
    required this.lamports,
    required this.priceUsd,
    required this.priceChange24h,
    required this.at,
  });
}

/// Survives a cold start so the first frame has real numbers.
///
/// Keyed by address: showing wallet A's balance under wallet B's name for the
/// half-second before the fetch lands is worse than showing nothing.
class PortfolioCache {
  const PortfolioCache._();

  static const _prefix = 'portfolio_snapshot_';

  static Future<PortfolioSnapshot?> read(String address) async {
    try {
      final raw = (await SharedPreferences.getInstance())
          .getStringList('$_prefix$address');
      if (raw == null || raw.length != 4) return null;

      final lamports = int.tryParse(raw[0]);
      final priceUsd = double.tryParse(raw[1]);
      final change = double.tryParse(raw[2]);
      final atMs = int.tryParse(raw[3]);
      if (lamports == null || priceUsd == null || change == null || atMs == null) {
        return null;
      }

      return PortfolioSnapshot(
        lamports: lamports,
        priceUsd: priceUsd,
        priceChange24h: change,
        at: DateTime.fromMillisecondsSinceEpoch(atMs),
      );
    } catch (e) {
      // A cache that cannot be read is a cache miss, never an error worth
      // showing — the fetch below it is the real answer either way.
      debugLog('[Portfolio] could not read the cache: $e');
      return null;
    }
  }

  static Future<void> write(
    String address, {
    required int lamports,
    required double priceUsd,
    required double priceChange24h,
    DateTime? at,
  }) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(
        '$_prefix$address',
        [
          '$lamports',
          '$priceUsd',
          '$priceChange24h',
          '${(at ?? DateTime.now()).millisecondsSinceEpoch}',
        ],
      );
    } catch (e) {
      debugLog('[Portfolio] could not write the cache: $e');
    }
  }

  static Future<void> clear(String address) async {
    try {
      await (await SharedPreferences.getInstance()).remove('$_prefix$address');
    } catch (e) {
      debugLog('[Portfolio] could not clear the cache: $e');
    }
  }
}
