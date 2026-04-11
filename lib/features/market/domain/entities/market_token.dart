
class MarketToken {
  final String id;
  final String name;
  final String symbol;
  final String imageUrl;
  final double currentPrice;
  final double priceChangePercentage24h;
  final double marketCap;
  final double volume24h;
  final List<double> sparklineData;

  const MarketToken({
    required this.id,
    required this.name,
    required this.symbol,
    required this.imageUrl,
    required this.currentPrice,
    required this.priceChangePercentage24h,
    required this.marketCap,
    required this.volume24h,
    required this.sparklineData,
  });
}