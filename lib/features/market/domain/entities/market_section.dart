import 'package:solfare/features/market/domain/entities/market_category.dart';

/// How a section presents itself on the market home.
enum MarketSectionStyle {
  /// A horizontal run of cards — a few things, seen at a glance.
  cards,

  /// Full-width rows with price and volume, for the sections people read rather
  /// than glance at.
  rows,
}

/// One band of the market home.
enum MarketSection {
  watchlist('Watchlist', MarketSectionStyle.rows),
  trending('Trending', MarketSectionStyle.rows),
  majorCrypto('Major crypto', MarketSectionStyle.cards),
  stocks('Stocks', MarketSectionStyle.cards),
  etfs('ETFs', MarketSectionStyle.cards),
  commodities('Commodities', MarketSectionStyle.cards),
  mostTraded('Most traded', MarketSectionStyle.cards);

  const MarketSection(this.title, this.style);

  final String title;
  final MarketSectionStyle style;

  /// The registry shelf behind this section, or null when it comes from a live
  /// feed or from the user's own list.
  MarketCategory? get shelf => switch (this) {
        MarketSection.majorCrypto => MarketCategory.majorCrypto,
        MarketSection.stocks => MarketCategory.stocks,
        MarketSection.etfs => MarketCategory.etfs,
        MarketSection.commodities => MarketCategory.commodities,
        MarketSection.watchlist => null,
        MarketSection.trending => null,
        MarketSection.mostTraded => null,
      };

  MarketFeed? get feed => switch (this) {
        MarketSection.trending => MarketFeed.trending,
        MarketSection.mostTraded => MarketFeed.topTraded,
        _ => null,
      };

  /// True when the section is assembled from mints the user starred rather than
  /// from anything the API ranks.
  bool get isWatchlist => this == MarketSection.watchlist;

  /// How many rows the home shows before the chevron.
  int get previewCount => style == MarketSectionStyle.rows ? 5 : 8;

  /// Sections rendered on the home, in order.
  static const List<MarketSection> home = [
    MarketSection.watchlist,
    MarketSection.trending,
    MarketSection.majorCrypto,
    MarketSection.stocks,
    MarketSection.etfs,
    MarketSection.commodities,
    MarketSection.mostTraded,
  ];
}
