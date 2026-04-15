class SplToken {
  final String mint;
  final String name;
  final String symbol;
  final String? imageUrl;
  final double balance;
  final int decimals;
  final double priceUsd;
  final double priceChange24h;

  const SplToken({
    required this.mint,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.decimals,
    this.imageUrl,
    this.priceUsd = 0,
    this.priceChange24h = 0,
  });

  double get valueUsd => balance * priceUsd;

  SplToken copyWith({
    double? balance,
    double? priceUsd,
    double? priceChange24h,
  }) {
    return SplToken(
      mint: mint,
      name: name,
      symbol: symbol,
      imageUrl: imageUrl,
      balance: balance ?? this.balance,
      decimals: decimals,
      priceUsd: priceUsd ?? this.priceUsd,
      priceChange24h: priceChange24h ?? this.priceChange24h,
    );
  }
}

/// Well-known mints we always surface in the UI (even at zero balance) so that
/// users see a recognizable asset list on first launch.
class WellKnownMints {
  static const String usdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const String usdcMetadata = 'USDC';
}
