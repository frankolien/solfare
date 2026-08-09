import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/presentation/market_format.dart';

void main() {
  group('price', () {
    test('dollars keep two places and thousands separators', () {
      expect(MarketFormat.price(4361.11), r'$4,361.11');
      expect(MarketFormat.price(773.8412), r'$773.84');
      expect(MarketFormat.price(1), r'$1.00');
    });

    test('under a dollar it is three significant digits, not fixed decimals', () {
      expect(MarketFormat.price(0.00253), r'$0.00253');
      expect(MarketFormat.price(0.00238), r'$0.00238');
      expect(MarketFormat.price(0.0028), r'$0.0028');
      expect(MarketFormat.price(0.5), r'$0.50', reason: r'$0.5 reads like a typo');
    });

    test('below a tenth of a cent the zeros collapse into a subscript', () {
      expect(MarketFormat.price(0.000788), r'$0.0₃788');
      expect(MarketFormat.price(0.00001234), r'$0.0₄123');
    });

    test('a value that rounds up past the decade loses a zero, not a digit', () {
      // 0.00009999 to three significant digits is 0.000100 — one zero shorter.
      expect(MarketFormat.price(0.00009999), r'$0.0₃100');
    });

    test('zero and nonsense do not render as prices', () {
      expect(MarketFormat.price(0), r'$0');
      expect(MarketFormat.price(double.nan), '—');
      expect(MarketFormat.price(double.infinity), '—');
    });
  });

  group('compact', () {
    test('three significant digits, whatever the scale', () {
      expect(MarketFormat.compact(23200000), r'$23.2M');
      expect(MarketFormat.compact(2260000), r'$2.26M');
      expect(MarketFormat.compact(121000), r'$121K');
      expect(MarketFormat.compact(8190000), r'$8.19M');
      expect(MarketFormat.compact(1000000000), r'$1.00B');
    });

    test('negative net volume keeps its sign', () {
      expect(MarketFormat.compact(-4090), r'-$4.09K');
    });

    test('an unreported number is a dash, not a zero', () {
      expect(MarketFormat.compact(null), '—');
    });
  });

  group('percent', () {
    test('always signed', () {
      expect(MarketFormat.percent(8.94), '+8.94%');
      expect(MarketFormat.percent(-0.81), '-0.81%');
      expect(MarketFormat.percent(0), '+0.00%');
    });

    test('a four-figure pump is still readable', () {
      expect(MarketFormat.percent(14302.84), '+14,302.84%');
    });
  });

  group('age', () {
    final now = DateTime.utc(2026, 8, 9, 12);

    test('reads at the resolution people ask about', () {
      expect(MarketFormat.age(now.subtract(const Duration(days: 400)), now: now), '1y');
      expect(MarketFormat.age(now.subtract(const Duration(days: 280)), now: now), '9mo');
      expect(MarketFormat.age(now.subtract(const Duration(days: 1)), now: now), '1d');
      expect(MarketFormat.age(now.subtract(const Duration(hours: 19)), now: now), '19h');
      expect(MarketFormat.age(now.subtract(const Duration(minutes: 3)), now: now), '3m');
      expect(MarketFormat.age(now.subtract(const Duration(seconds: 5)), now: now), 'new');
    });

    test('no creation date and a date in the future both give nothing', () {
      expect(MarketFormat.age(null, now: now), isNull);
      expect(MarketFormat.age(now.add(const Duration(days: 1)), now: now), isNull);
    });
  });
}
