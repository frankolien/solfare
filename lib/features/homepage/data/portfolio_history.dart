import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One point on the portfolio value graph.
class PortfolioSnapshot {
  final DateTime at;
  final double usdValue;

  const PortfolioSnapshot({required this.at, required this.usdValue});

  Map<String, dynamic> toJson() => {
        't': at.millisecondsSinceEpoch,
        'v': usdValue,
      };

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) =>
      PortfolioSnapshot(
        at: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        usdValue: (json['v'] as num).toDouble(),
      );
}

/// Tracks the user's total portfolio USD value over time.
///
/// Storage model: per-address JSON list in SharedPreferences. One snapshot
/// per hour max, retained for 90 days. Writes dedupe within the hour so
/// repeated price refreshes don't bloat the file.
class PortfolioHistory {
  PortfolioHistory._();
  static final PortfolioHistory instance = PortfolioHistory._();

  static const _prefix = 'portfolio_history_';
  static const _maxAgeDays = 90;
  static const _hourMs = 60 * 60 * 1000;

  String _key(String address) => '$_prefix$address';

  /// Append a snapshot for [address]. Overwrites the last entry if it fell
  /// within the same hour — we don't need 60 points per hour.
  Future<void> record(String address, double usdValue) async {
    if (address.isEmpty) return;
    if (usdValue.isNaN || usdValue.isInfinite) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = await _load(prefs, address);

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // Drop anything older than the retention window.
    final cutoff = nowMs - (_maxAgeDays * 24 * _hourMs);
    existing.removeWhere((s) => s.at.millisecondsSinceEpoch < cutoff);

    if (existing.isNotEmpty) {
      final last = existing.last;
      if (nowMs - last.at.millisecondsSinceEpoch < _hourMs) {
        // Same hour — overwrite with latest value.
        existing[existing.length - 1] =
            PortfolioSnapshot(at: now, usdValue: usdValue);
      } else {
        existing.add(PortfolioSnapshot(at: now, usdValue: usdValue));
      }
    } else {
      existing.add(PortfolioSnapshot(at: now, usdValue: usdValue));
    }

    await prefs.setString(
      _key(address),
      jsonEncode(existing.map((s) => s.toJson()).toList()),
    );
  }

  /// All retained snapshots for [address], oldest first.
  Future<List<PortfolioSnapshot>> load(String address) async {
    if (address.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs, address);
  }

  Future<List<PortfolioSnapshot>> _load(
    SharedPreferences prefs,
    String address,
  ) async {
    final raw = prefs.getString(_key(address));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PortfolioSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
