import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/currency/currency.dart';
import 'package:solfare/core/network/coingecko_client.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/util/json.dart';

/// The currency prices are shown in, and what one US dollar is worth in it.
///
/// See docs/design/round-two.md. Every price in the app arrives in USD — SOL
/// from CoinGecko, SPL tokens from Helius — so one rate converts all of them.
/// Asking each source for a different currency would put two sources'
/// disagreement about the rate on the same screen.
class CurrencyStore extends ChangeNotifier {
  CurrencyStore._();

  static final CurrencyStore instance = CurrencyStore._();

  static const _codeKey = 'display_currency';
  static const _ratePrefix = 'display_currency_rate_';

  Currency _selected = Currencies.usd;
  double _rate = 1;

  Currency get selected => _selected;

  /// Multiply a USD figure by this. Exactly 1 for USD, so the common path does
  /// no arithmetic at all.
  double get rate => _rate;

  /// Read the choice and its last known rate before the first frame.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selected = Currencies.byCode(prefs.getString(_codeKey));
      _rate = _selected.code == Currencies.usd.code
          ? 1
          : (prefs.getDouble('$_ratePrefix${_selected.code}') ?? 1);
    } catch (e) {
      debugLog('[Currency] could not read the selection: $e');
    }
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> select(Currency currency) async {
    if (currency.code == _selected.code) return;
    _selected = currency;
    // The stored rate first, so the screen changes the moment they pick rather
    // than after a round trip. Refreshed underneath.
    _rate = await _storedRate(currency);
    notifyListeners();

    try {
      await (await SharedPreferences.getInstance())
          .setString(_codeKey, currency.code);
    } catch (e) {
      debugLog('[Currency] could not save the selection: $e');
    }
    await refresh();
  }

  /// Re-price the selected currency against the dollar.
  Future<void> refresh() async {
    final currency = _selected;
    if (currency.code == Currencies.usd.code) {
      if (_rate != 1) {
        _rate = 1;
        notifyListeners();
      }
      return;
    }

    try {
      // Both legs in one request, so the ratio is taken from a single quote
      // rather than two that may be minutes apart.
      final json = await CoinGeckoClient.instance.getJson(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=solana&vs_currencies=usd,${currency.code}',
        ttl: const Duration(hours: 1),
      );

      final solana = json?.mapAt('solana');
      final usd = solana?.doubleAt('usd');
      final local = solana?.doubleAt(currency.code);
      if (usd == null || local == null || usd <= 0 || local <= 0) return;

      _rate = local / usd;
      notifyListeners();

      await (await SharedPreferences.getInstance())
          .setDouble('$_ratePrefix${currency.code}', _rate);
    } catch (e) {
      // A rate we cannot refresh is not a reason to render nothing. The stored
      // one is wrong by a fraction of a percent; a missing one blanks every
      // figure on the screen.
      debugLog('[Currency] could not refresh the rate: $e');
    }
  }

  Future<double> _storedRate(Currency currency) async {
    if (currency.code == Currencies.usd.code) return 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('$_ratePrefix${currency.code}') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  @visibleForTesting
  void setForTest(Currency currency, double rate) {
    _selected = currency;
    _rate = rate;
    notifyListeners();
  }
}
