/// The shelves the market splits into.
///
/// Jupiter serves the mints but not the split. Its tag endpoint answers only
/// for `verified` and `lst`, and the tags on the tokens themselves file gold
/// under `stocks`, so anything past [tokens] is assembled here from a bundled
/// registry of mints.
enum MarketCategory {
  /// Not on a shelf — whatever a live feed returned.
  tokens('Tokens'),
  majorCrypto('Major crypto'),
  stocks('Stocks'),
  etfs('ETFs'),
  commodities('Commodities');

  const MarketCategory(this.label);

  final String label;

  /// True when the rows come from a live feed rather than the registry, and
  /// so have an ordering to ask the API for.
  bool get isFeedDriven => this == MarketCategory.tokens;

  /// Whether a mint on this shelf has to still read as a real-world asset.
  ///
  /// Wrapped BTC is not tagged `rwa` and never will be, so applying the
  /// tokenised-equity check to major crypto would empty the shelf.
  bool get requiresRwaTag => switch (this) {
        MarketCategory.stocks => true,
        MarketCategory.etfs => true,
        MarketCategory.commodities => true,
        MarketCategory.tokens => false,
        MarketCategory.majorCrypto => false,
      };
}

/// The orderings Jupiter publishes for [MarketCategory.tokens].
enum MarketFeed {
  trending('Trending', 'toptrending'),
  topTraded('Most traded', 'toptraded'),
  organic('Organic', 'toporganicscore');

  const MarketFeed(this.label, this.path);

  final String label;

  /// Path segment under `/tokens/v2`.
  final String path;
}
