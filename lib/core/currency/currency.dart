/// A fiat currency the app can display prices in.
class Currency {
  /// Lowercase, as CoinGecko's `vs_currencies` expects it.
  final String code;

  final String symbol;
  final String name;

  const Currency(this.code, this.symbol, this.name);

  String get display => code.toUpperCase();
}

/// Every currency offered, all of which CoinGecko quotes directly.
///
/// Deliberately a bundled list rather than whatever the API happens to return:
/// the picker has to render before any network call, and a currency we cannot
/// price is one the user can select and then see nothing in.
class Currencies {
  const Currencies._();

  static const usd = Currency('usd', r'$', 'US Dollar');

  static const all = <Currency>[
    usd,
    Currency('eur', '€', 'Euro'),
    Currency('gbp', '£', 'British Pound'),
    Currency('ngn', '₦', 'Nigerian Naira'),
    Currency('ghs', '₵', 'Ghanaian Cedi'),
    Currency('kes', 'KSh', 'Kenyan Shilling'),
    Currency('zar', 'R', 'South African Rand'),
    Currency('inr', '₹', 'Indian Rupee'),
    Currency('idr', 'Rp', 'Indonesian Rupiah'),
    Currency('php', '₱', 'Philippine Peso'),
    Currency('vnd', '₫', 'Vietnamese Dong'),
    Currency('jpy', '¥', 'Japanese Yen'),
    Currency('cny', '¥', 'Chinese Yuan'),
    Currency('krw', '₩', 'South Korean Won'),
    Currency('brl', r'R$', 'Brazilian Real'),
    Currency('mxn', r'MX$', 'Mexican Peso'),
    Currency('cad', r'CA$', 'Canadian Dollar'),
    Currency('aud', r'A$', 'Australian Dollar'),
    Currency('try', '₺', 'Turkish Lira'),
    Currency('aed', 'AED', 'UAE Dirham'),
  ];

  static Currency byCode(String? code) => all.firstWhere(
        (c) => c.code == code,
        orElse: () => usd,
      );

  /// Currencies whose smallest unit makes cents meaningless — a rupiah or a
  /// dong figure with two decimals is noise, not precision.
  static const _wholeUnit = {'idr', 'vnd', 'jpy', 'krw', 'ngn'};

  static int decimalsFor(Currency c) => _wholeUnit.contains(c.code) ? 0 : 2;
}
