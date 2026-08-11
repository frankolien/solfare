import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/features/wallet/data/datasource/portfolio_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const a = '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB';
  const b = 'HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a written snapshot reads back whole', () async {
    await PortfolioCache.write(a,
        lamports: 1500000000, priceUsd: 86.29, priceChange24h: -2.5);

    final got = await PortfolioCache.read(a);
    expect(got, isNotNull);
    expect(got!.lamports, 1500000000);
    expect(got.priceUsd, 86.29);
    expect(got.priceChange24h, -2.5);
  });

  test('one wallet never serves another wallet its balance', () async {
    // The failure this guards: showing A's number under B's name for the
    // half-second before B's fetch lands.
    await PortfolioCache.write(a,
        lamports: 5000000000, priceUsd: 86.29, priceChange24h: 0);

    expect(await PortfolioCache.read(b), isNull);
  });

  test('an address with nothing stored is a miss, not a zero', () async {
    expect(await PortfolioCache.read(a), isNull);
  });

  test('a later write replaces the earlier one', () async {
    await PortfolioCache.write(a,
        lamports: 1, priceUsd: 10, priceChange24h: 0);
    await PortfolioCache.write(a,
        lamports: 2, priceUsd: 20, priceChange24h: 1);

    expect((await PortfolioCache.read(a))!.lamports, 2);
  });

  test('a truncated entry is a miss rather than a crash', () async {
    SharedPreferences.setMockInitialValues({
      'portfolio_snapshot_$a': ['1500000000', '86.29'],
    });

    expect(await PortfolioCache.read(a), isNull);
  });

  test('an unparseable entry is a miss rather than a crash', () async {
    SharedPreferences.setMockInitialValues({
      'portfolio_snapshot_$a': ['not-a-number', '86.29', '0', '1700000000000'],
    });

    expect(await PortfolioCache.read(a), isNull);
  });

  test('clearing removes it', () async {
    await PortfolioCache.write(a,
        lamports: 1, priceUsd: 10, priceChange24h: 0);
    await PortfolioCache.clear(a);

    expect(await PortfolioCache.read(a), isNull);
  });

  test('the timestamp survives, so age can be judged later', () async {
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    await PortfolioCache.write(a,
        lamports: 1, priceUsd: 10, priceChange24h: 0, at: at);

    expect((await PortfolioCache.read(a))!.at, at);
  });
}
