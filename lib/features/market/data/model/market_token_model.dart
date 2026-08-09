import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

/// Parses Jupiter's token API v2 shape.
class MarketTokenModel extends MarketToken {
  const MarketTokenModel({
    required super.id,
    required super.name,
    required super.symbol,
    required super.imageUrl,
    required super.currentPrice,
    super.decimals,
    super.tokenProgram,
    super.isVerified,
    super.marketCap,
    super.liquidity,
    super.holderCount,
    super.organicScore,
    super.createdAt,
    super.category,
    super.stats,
  });

  /// [category] is supplied by the caller: the feed endpoints only ever return
  /// tokens, and the shelves come from the registry rather than the payload.
  factory MarketTokenModel.fromJupiter(
    Map<String, dynamic> json, {
    MarketCategory category = MarketCategory.tokens,
  }) {
    final symbol = json['symbol'] as String? ?? '';
    return MarketTokenModel(
      id: json['id'] as String? ?? '',
      // An empty name would render as a blank row, and the mint alone reads
      // as nothing at all, so the ticker is the better fallback.
      name: _nonEmpty(json['name']) ?? symbol,
      symbol: symbol,
      imageUrl: json['icon'] as String? ?? '',
      currentPrice: _num(json['usdPrice']) ?? 0,
      decimals: (json['decimals'] as num?)?.toInt() ?? 0,
      tokenProgram: json['tokenProgram'] as String? ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      marketCap: _num(json['mcap']) ?? _num(json['fdv']),
      liquidity: _num(json['liquidity']),
      holderCount: (json['holderCount'] as num?)?.toInt(),
      organicScore: _num(json['organicScore']),
      // The first pool is when the token became tradeable; the mint can
      // predate it. Trading age is the one being asked about.
      createdAt: _time((json['firstPool'] as Map<String, dynamic>?)?['createdAt']) ??
          _time(json['createdAt']),
      category: category,
      stats: {
        for (final window in MarketWindow.values)
          if (json[_statsKey(window)] case final Map<String, dynamic> block)
            window: _stats(block),
      },
    );
  }

  /// The tags the payload carried, used to recheck a registry entry still
  /// belongs on the shelf this file was told to put it on.
  static List<String> tagsOf(Map<String, dynamic> json) =>
      ((json['tags'] as List?) ?? const []).whereType<String>().toList();

  static String _statsKey(MarketWindow window) => switch (window) {
        MarketWindow.m5 => 'stats5m',
        MarketWindow.h1 => 'stats1h',
        MarketWindow.h6 => 'stats6h',
        MarketWindow.h24 => 'stats24h',
      };

  static MarketStats _stats(Map<String, dynamic> json) => MarketStats(
        priceChange: _num(json['priceChange']) ?? 0,
        buyVolume: _num(json['buyVolume']) ?? 0,
        sellVolume: _num(json['sellVolume']) ?? 0,
        numBuys: (json['numBuys'] as num?)?.toInt() ?? 0,
        numSells: (json['numSells'] as num?)?.toInt() ?? 0,
        numTraders: (json['numTraders'] as num?)?.toInt() ?? 0,
      );

  /// Null stays null. A market cap the API declined to report is not zero.
  static double? _num(dynamic value) => (value as num?)?.toDouble();

  static DateTime? _time(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static String? _nonEmpty(dynamic value) {
    final s = value as String?;
    return (s == null || s.isEmpty) ? null : s;
  }
}
