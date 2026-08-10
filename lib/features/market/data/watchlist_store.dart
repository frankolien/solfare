import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/util/app_log.dart';

/// The mints somebody starred.
class WatchlistStore {
  WatchlistStore._();

  static final WatchlistStore instance = WatchlistStore._();

  static const _key = 'market_watchlist';

  /// Insertion order, not market cap.
  final ValueNotifier<List<String>> mints = ValueNotifier<List<String>>(const []);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      mints.value = prefs.getStringList(_key) ?? const [];
    } catch (e) {
      // An unreadable watchlist costs a few stars.
      debugLog('[Watchlist] could not read: $e');
    }
  }

  bool contains(String mint) => mints.value.contains(mint);

  Future<void> toggle(String mint) =>
      contains(mint) ? remove(mint) : add(mint);

  Future<void> add(String mint) async {
    if (mint.isEmpty || contains(mint)) return;
    await _write([...mints.value, mint]);
  }

  Future<void> remove(String mint) async {
    if (!contains(mint)) return;
    await _write([...mints.value]..remove(mint));
  }

  Future<void> clear() => _write(const []);

  Future<void> _write(List<String> next) async {
    // The notifier moves first.
    mints.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next);
    } catch (e) {
      debugLog('[Watchlist] could not write: $e');
    }
  }

  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    mints.value = const [];
  }
}
