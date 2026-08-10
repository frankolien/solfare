/// Number and date formatting shared by the market list, the detail screen and
/// the buy sheet, so a price reads the same everywhere it appears.
class MarketFormat {
  const MarketFormat._();

  static const _subscripts = '₀₁₂₃₄₅₆₇₈₉';

  // Where the subscript notation stops being useful.
  static const int _maxSubscriptZeros = 18;

  /// A price with as much precision as it needs and no more.
  static String price(double value) {
    if (value.isNaN || value.isInfinite) return '—';
    if (value == 0) return r'$0';
    final magnitude = value.abs();
    final sign = value < 0 ? '-' : '';

    if (magnitude >= 1) return '$sign\$${_grouped(magnitude, 2)}';

    var scaled = magnitude;
    var zeros = 0;
    while (scaled < 0.1 && zeros < _maxSubscriptZeros) {
      scaled *= 10;
      zeros++;
    }

    // Past the point the notation can express.
    if (scaled < 0.1) {
      return '$sign<\$0.0${_subscript(_maxSubscriptZeros)}1';
    }

    var digits = (scaled * 1000).round();
    // 0.0999… rounds to 1000, which is 0.1 and one zero shorter.
    if (digits >= 1000) {
      digits = 100;
      zeros--;
    }

    // Three significant digits, wherever they start.
    if (zeros < 3) return '$sign\$${_trimmed(magnitude, zeros + 3)}';

    return '$sign\$0.0${_subscript(zeros)}$digits';
  }

  /// Large money, three significant digits: `$23.2M`, `$2.26M`, `$121K`.
  static String compact(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return '—';
    final magnitude = value.abs();
    final sign = value < 0 ? '-' : '';

    const units = [(1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')];
    for (final (threshold, suffix) in units) {
      // 999.5 rather than 1.0 of the threshold: _significant rounds to three
      // digits, so anything from 999,500 up rendered as "$1000K" rather than
      // promoting to "$1M".
      if (magnitude >= threshold * 999.5 / 1000) {
        return '$sign\$${_significant(magnitude / threshold)}$suffix';
      }
    }
    return '$sign\$${magnitude.toStringAsFixed(magnitude >= 100 ? 0 : 2)}';
  }

  /// Signed, so a flat market does not read as a gain.
  static String percent(double value) {
    if (value.isNaN || value.isInfinite) return '—';
    return '${value >= 0 ? '+' : '-'}${_grouped(value.abs(), 2)}%';
  }

  /// How long the token has existed, at the resolution people actually ask
  /// about: `2h`, `19h`, `1d`, `9mo`, `1y`.
  static String? age(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return null;
    final elapsed = (now ?? DateTime.now()).difference(createdAt);
    if (elapsed.isNegative) return null;

    final days = elapsed.inDays;
    if (days >= 365) return '${days ~/ 365}y';
    if (days >= 30) return '${days ~/ 30}mo';
    if (days >= 1) return '${days}d';
    if (elapsed.inHours >= 1) return '${elapsed.inHours}h';
    if (elapsed.inMinutes >= 1) return '${elapsed.inMinutes}m';
    return 'new';
  }

  /// Shortens a mint for display without pretending it is a name.
  static String shortMint(String mint) =>
      mint.length <= 12 ? mint : '${mint.substring(0, 4)}…${mint.substring(mint.length - 4)}';

  // Fixed to [decimals], then stripped back to what the number says, but never
  // past two places — `$0.5` reads like a typo where `$0.50` does not.
  static String _trimmed(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);
    while (text.contains('.') && text.endsWith('0') && text.split('.')[1].length > 2) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  static String _significant(double value) {
    if (value >= 100) return value.toStringAsFixed(0);
    if (value >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  static String _subscript(int count) =>
      count.toString().split('').map((d) => _subscripts[int.parse(d)]).join();

  static String _grouped(double value, int decimals) {
    final text = value.toStringAsFixed(decimals);
    final dot = text.indexOf('.');
    final whole = dot == -1 ? text : text.substring(0, dot);
    final rest = dot == -1 ? '' : text.substring(dot);

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '$buffer$rest';
  }
}
