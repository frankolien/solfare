import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

/// What the list is ordered by.
///
/// [volume] and [priceChange] are read from the selected window's stats, so
/// the same key means something different under 5m than under 24h. That is
/// what the window chips are for.
enum MarketSort {
  /// The order the feed itself returned. Trending is a ranking Jupiter
  /// computes and we cannot reproduce, so leaving it alone is the only way to
  /// show it.
  rank('Rank'),
  marketCap('Mkt cap'),
  volume('Volume'),
  priceChange('Change'),
  liquidity('Liquidity'),
  holders('Holders'),
  organicScore('Organic');

  const MarketSort(this.label);

  final String label;
}

/// Orders [tokens] by [sort] as measured over [window].
///
/// A value the API did not report sorts last in both directions. Treating it
/// as zero would float unknowns to the top of an ascending sort, where they
/// would read as the smallest rather than the unmeasured.
List<MarketToken> sortMarketTokens(
  List<MarketToken> tokens, {
  required MarketSort sort,
  required MarketWindow window,
  bool descending = true,
}) {
  // Reversing rather than sorting: Dart's sort is not stable, so running it
  // over values that all compare equal would shuffle the feed's ranking.
  if (sort == MarketSort.rank) {
    return descending ? List<MarketToken>.of(tokens) : tokens.reversed.toList();
  }

  double? valueOf(MarketToken t) => switch (sort) {
        MarketSort.rank => null,
        MarketSort.marketCap => t.marketCap,
        MarketSort.volume => t.stats.containsKey(window) ? t.volume(window) : null,
        MarketSort.priceChange => t.stats.containsKey(window) ? t.priceChange(window) : null,
        MarketSort.liquidity => t.liquidity,
        MarketSort.holders => t.holderCount?.toDouble(),
        MarketSort.organicScore => t.organicScore,
      };

  final sorted = List<MarketToken>.from(tokens);
  sorted.sort((a, b) {
    final va = valueOf(a);
    final vb = valueOf(b);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;
    return descending ? vb.compareTo(va) : va.compareTo(vb);
  });
  return sorted;
}
