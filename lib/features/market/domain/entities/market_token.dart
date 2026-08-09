import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

/// One asset in the market list.
///
/// [id] is the mint. Every row is a real Solana token, which is the whole
/// reason a buy button can exist on it: a mint plus decimals is everything an
/// order needs.
class MarketToken {
  /// The mint address.
  final String id;
  final String name;
  final String symbol;
  final String imageUrl;
  final double currentPrice;
  final int decimals;

  /// SPL Token or Token-2022. Needed before a transfer, not before a swap,
  /// but carried so the send path never has to look it up again.
  final String tokenProgram;

  /// Jupiter's own verification. Unverified mints are shown but marked.
  final bool isVerified;

  /// Null when the API did not report one — an unknown supply leaves market
  /// cap unknowable, and zero would be a different claim.
  final double? marketCap;
  final double? liquidity;
  final int? holderCount;

  /// 0–100. How much of the volume comes from real traders rather than wash.
  final double? organicScore;

  /// When the mint first traded. Age is most of what separates a blue chip
  /// from something that launched this morning.
  final DateTime? createdAt;

  /// Which shelf this was loaded onto.
  final MarketCategory category;

  final Map<MarketWindow, MarketStats> stats;

  /// Only ever populated by the CoinGecko path the detail chart still uses.
  final List<double> sparklineData;

  const MarketToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.imageUrl,
    required this.currentPrice,
    this.decimals = 0,
    this.tokenProgram = '',
    this.isVerified = false,
    this.marketCap,
    this.liquidity,
    this.holderCount,
    this.organicScore,
    this.createdAt,
    this.category = MarketCategory.tokens,
    this.stats = const {},
    this.sparklineData = const [],
  });

  MarketStats statsFor(MarketWindow window) => stats[window] ?? const MarketStats();

  double priceChange(MarketWindow window) => statsFor(window).priceChange;

  double volume(MarketWindow window) => statsFor(window).volume;

  /// Kept because the detail screen and the trending cards speak in days.
  double get priceChangePercentage24h => priceChange(MarketWindow.h24);

  double get volume24h => volume(MarketWindow.h24);

  @override
  String toString() => '$symbol ${id.substring(0, 4)}… \$$currentPrice';
}
