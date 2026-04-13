class SwapToken {
  final String mint;
  final String symbol;
  final String name;
  final int decimals;
  final String? logoUrl;
  final double? priceUsd;

  const SwapToken({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.logoUrl,
    this.priceUsd,
  });

  // Native SOL
  static const sol = SwapToken(
    mint: 'So11111111111111111111111111111111111111112',
    symbol: 'SOL',
    name: 'Solana',
    decimals: 9,
    logoUrl: 'https://assets.coingecko.com/coins/images/4128/large/solana.png',
  );

  // USDC on Solana
  static const usdc = SwapToken(
    mint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 6,
    logoUrl: 'https://assets.coingecko.com/coins/images/6319/large/usdc.png',
  );
}
