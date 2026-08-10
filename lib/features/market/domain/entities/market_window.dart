enum MarketWindow {
  m5('5m'),
  h1('1h'),
  h6('6h'),
  h24('24h');

  const MarketWindow(this.label);

  /// Shown on the chips, and also the path segment the feed endpoints take.
  final String label;
}

/// What happened to one asset over one window.
class MarketStats {
  /// Signed percentage.
  final double priceChange;
  final double buyVolume;
  final double sellVolume;
  final int numBuys;
  final int numSells;
  final int numTraders;

  const MarketStats({
    this.priceChange = 0,
    this.buyVolume = 0,
    this.sellVolume = 0,
    this.numBuys = 0,
    this.numSells = 0,
    this.numTraders = 0,
  });

  double get volume => buyVolume + sellVolume;

  /// Buying minus selling.
  double get netVolume => buyVolume - sellVolume;

  @override
  String toString() => 'MarketStats(${priceChange.toStringAsFixed(2)}%, vol $volume)';
}
