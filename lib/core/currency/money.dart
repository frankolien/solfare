import 'package:solfare/core/currency/currency.dart';
import 'package:solfare/core/currency/currency_store.dart';

/// Renders a USD figure in whatever currency the user picked.
///
/// One place, because money was formatted by hand at fourteen call sites with
/// a literal `$` and `toStringAsFixed(2)`, which is fourteen chances to
/// disagree about what a number means.
class Money {
  const Money._();

  /// [usd] converted, grouped, and prefixed with the currency's symbol.
  static String format(double usd, {bool grouped = true}) {
    final store = CurrencyStore.instance;
    final currency = store.selected;
    final value = usd * store.rate;
    final decimals = Currencies.decimalsFor(currency);
    // The sign belongs outside the symbol: "$-1,234.50" reads as a broken
    // string, "-$1,234.50" reads as a debit.
    final negative = value < 0;
    final text = value.abs().toStringAsFixed(decimals);
    final body = grouped ? _group(text) : text;
    return '${negative ? '-' : ''}${currency.symbol}$body';
  }

  /// Signed, for a change over a period: `+₦1,240` / `-₦310`.
  static String formatChange(double usd) {
    final sign = usd < 0 ? '-' : '+';
    return '$sign${format(usd.abs())}';
  }

  /// A price, which needs more precision than a holding: a token worth
  /// fractions of a cent renders as 0.00 at two decimals and looks worthless.
  static String formatPrice(double usd) {
    final store = CurrencyStore.instance;
    final value = usd * store.rate;
    final symbol = store.selected.symbol;
    if (value == 0) return '$symbol${0.toStringAsFixed(2)}';
    if (value.abs() >= 1) return format(usd);
    // Enough decimals to show three significant digits.
    var decimals = 2;
    var scaled = value.abs();
    while (scaled < 0.1 && decimals < 10) {
      scaled *= 10;
      decimals++;
    }
    return '$symbol${value.toStringAsFixed(decimals + 1)}';
  }

  static String _group(String text) {
    final dot = text.indexOf('.');
    final whole = dot == -1 ? text : text.substring(0, dot);
    final rest = dot == -1 ? '' : text.substring(dot);
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buffer$rest';
  }
}
