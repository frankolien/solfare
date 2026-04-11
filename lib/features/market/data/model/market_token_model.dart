import 'package:solfare/features/market/domain/entities/market_token.dart';

class MarketTokenModel extends MarketToken {
  const MarketTokenModel({
    required super.id,
    required super.name,
    required super.symbol,
    required super.imageUrl,
    required super.currentPrice,
    required super.priceChangePercentage24h,
    required super.marketCap,
    required super.volume24h,
    required super.sparklineData,
  });

  /// Maps CoinGecko's snake_case JSON keys to our Dart fields
  factory MarketTokenModel.fromJson(Map<String, dynamic> json) {
    // Parse sparkline — nested under 'sparkline_in_7d' -> 'price'
    List<double> sparkline = [];
    if (json['sparkline_in_7d'] != null && json['sparkline_in_7d']['price'] != null) {
      sparkline = (json['sparkline_in_7d']['price'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return MarketTokenModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      priceChangePercentage24h: (json['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0,
      marketCap: (json['market_cap'] as num?)?.toDouble() ?? 0.0,
      volume24h: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
      sparklineData: sparkline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'image': imageUrl,
      'current_price': currentPrice,
      'price_change_percentage_24h': priceChangePercentage24h,
      'market_cap': marketCap,
      'total_volume': volume24h,
      'sparkline_in_7d': {'price': sparklineData},
    };
  }
}
