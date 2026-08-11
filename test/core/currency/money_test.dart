import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/currency/currency.dart';
import 'package:solfare/core/currency/currency_store.dart';
import 'package:solfare/core/currency/money.dart';

void main() {
  tearDown(() => CurrencyStore.instance.setForTest(Currencies.usd, 1));

  test('dollars pass through untouched', () {
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.format(76.06), r'$76.06');
  });

  test('a naira figure is converted, grouped and left whole', () {
    // Rupiah, naira, yen and won have no meaningful sub-unit here: "₦114,090.00"
    // is two digits of noise on every screen.
    CurrencyStore.instance.setForTest(Currencies.byCode('ngn'), 1500);
    expect(Money.format(76.06), '₦114,090');
  });

  test('grouping survives the decimal point', () {
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.format(1234567.5), r'$1,234,567.50');
  });

  test('a negative figure keeps its sign outside the grouping', () {
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.format(-1234.5), r'-$1,234.50');
  });

  test('a change carries an explicit sign', () {
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.formatChange(12.3), r'+$12.30');
    expect(Money.formatChange(-12.3), r'-$12.30');
  });

  test('a sub-cent price does not round to nothing', () {
    // A token worth fractions of a cent renders as $0.00 at two decimals and
    // reads as worthless.
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.formatPrice(0.0000123), isNot(r'$0.00'));
    expect(Money.formatPrice(0.0000123), contains('123'));
  });

  test('an ordinary price is just the ordinary format', () {
    CurrencyStore.instance.setForTest(Currencies.usd, 1);
    expect(Money.formatPrice(76.06), r'$76.06');
  });

  test('an unknown code falls back to dollars rather than blanking', () {
    expect(Currencies.byCode('zzz').code, 'usd');
    expect(Currencies.byCode(null).code, 'usd');
  });

  test('every offered currency has a symbol and a name', () {
    for (final c in Currencies.all) {
      expect(c.symbol, isNotEmpty, reason: c.code);
      expect(c.name, isNotEmpty, reason: c.code);
      expect(c.code, equals(c.code.toLowerCase()),
          reason: 'CoinGecko takes vs_currencies lowercase');
    }
  });
}
