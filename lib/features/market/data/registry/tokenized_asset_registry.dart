import 'package:solfare/features/market/domain/entities/market_category.dart';

/// Mints that Jupiter serves but does not shelve.
///
/// `/tokens/v2/tag` accepts only `verified` and `lst`, and the tags carried by
/// the tokens themselves disagree with each other about what a commodity is —
/// three gold tokens come back tagged `stocks`, `commodities` and neither. So
/// the split the user sees is made here.
///
/// This file ships mints and shelves. Names, decimals and prices are hydrated
/// from the API on every load, because a bundled price is a stale price.
class TokenizedAssetRegistry {
  const TokenizedAssetRegistry._();

  /// A registry entry is a claim about the world made when this file was
  /// written. On load the claim is rechecked against these tags, and an entry
  /// that no longer carries one is dropped rather than left on a shelf it has
  /// stopped belonging to.
  static const Set<String> rwaTags = {
    'stocks',
    'equities',
    'commodities',
    'rwa',
    'xstocks',
    'ondo',
  };

  /// Tokenised equities. xStocks are issued by Backed Finance; the Ondo
  /// tokens are their own programme.
  static const List<String> _stocks = [
    'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W', // SPYx    S&P 500
    'Xs8S1uUs1zvS2p7iwtsG3b6fkhpvmwz4GYU3gWAmWHZ', // QQQx    Nasdaq 100
    'Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh', // NVDAx   NVIDIA
    'XsueG8BtpquVJX9LVLLEGuViXUungE6WmK5YZ3p3bd1', // CRCLx   Circle
    'XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB', // TSLAx   Tesla
    'XsP7xzNPvEHS1m6qfanPUGjNmdnmsLKEoNAnHjdxxyZ', // MSTRx   MicroStrategy
    'Xs7ZdzSHLU9ftNJsii5fCeJhoRWSC32SQGzGQtePxNu', // COINx   Coinbase
    'XsvNBAYkrDRNhA7wPHQfX3ZUXZyZLdnCQDfHZ56bzpg', // HOODx   Robinhood
    'XsCPL9dNWBMvFtTmwcCA5v3xWPSMEBCszbQdiLLq6aN', // GOOGLx  Alphabet
    'XspzcW1PRtgf6Wj92HCiZdjzKCyFekVD8P5Ueh3dRMX', // MSFTx   Microsoft
    'Xs3eBt7uRfJX8QUs4suhyU8p2M6DoUDrJyWBa8LLZsg', // AMZNx   Amazon
    'XsoBhf2ufR8fTyNSjqfU71DYGaE6Z3SUGAidpzriAA4', // PLTRx   Palantir
    'XsqE9cRRpzxcGKDXj1BJ7Xmg4GRhZoyY1KpmGSxAWT2', // MCDx    McDonald's
    'XsbEhLAtcf6HdfpFZ5xEMdqW8nfAvcsP5bdudRLJzJp', // AAPLx   Apple
    'XsgSaSvNSqLTtFuyWPBhK9196Xb9Bbdyjj4fH3cPJGo', // AVGOx   Broadcom
    'Xsa62P5mvPszXL1krVUnU5ar38bBSVcWAB6fmPCo5Zu', // METAx   Meta
    'Xs6B6zawENwAbWVi7w92rjazLuAr5Az59qgWKcNb45x', // BRK.Bx  Berkshire Hathaway
    'XsjFwUPiLofddX5cWFHW35GCbXcSu1BCUGfxoQAQjeL', // ORCLx   Oracle
    'XsXcJ6GZ9kVnjqGsjBnktRcuwMBmvKWh8S93RefZ1rF', // AMDx    AMD
    'XsEH7wWfJJu2ZT3UCFeVfALnVA6CP5ur7Ee11KmzVpL', // NFLXx   Netflix
    'XsGVi5eo1Dh2zUpic4qACcjuWGjNv8GCt3dm5XcX6Dn', // JNJx    Johnson & Johnson
    'XsjQP3iMAaQ3kQScQKthQpx9ALRbjKAjQtHg6TFomoc', // TQQQx   ProShares UltraPro QQQ
  ];

  /// Precious metals. Energy and agriculture have no verified mint on Solana
  /// that this registry could point at, so they are not offered.
  static const List<String> _commodities = [
    'AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P', // XAUt0  Tether Gold
    '5GgRAEmv8ZxF2PR5hY72Qs5x1bnQ6UK2RbTPoqJ3wSwW', // PAXG   PAX Gold
    'Xsv9hRk1z5ystj9MhnA7Lq4vjSsLwzL2nxrwmwtD3re', // GLDx   Gold xStock
    'hWfiw4mcxT8rnNFkk6fsCQSxoxgZ9yVhB6tyeVcondo', // GLDon  SPDR Gold Shares
    'M77ZvkZ8zW5udRbuJCbuwSwavRa7bGAZYMTwru8ondo', // IAUon  iShares Gold Trust
    'XsxAd6okt8y1RRK6gNg7iJaqiWNiq5Md5EDf3ZrF2dm', // SLVx   iShares Silver Trust
    'Xst6eFD4YT6sz9RLMysN9SyvaZWtraSdVJQGu5ZkAme', // PPLTx  abrdn Physical Platinum
  ];

  static List<String> mintsFor(MarketCategory category) => switch (category) {
        MarketCategory.stocks => _stocks,
        MarketCategory.commodities => _commodities,
        MarketCategory.tokens => const [],
      };

  static MarketCategory? categoryOf(String mint) {
    if (_stocks.contains(mint)) return MarketCategory.stocks;
    if (_commodities.contains(mint)) return MarketCategory.commodities;
    return null;
  }

  /// Whether [tags] still support shelving a mint as a real-world asset.
  static bool tagsSupportRwa(Iterable<String> tags) =>
      tags.any(rwaTags.contains);
}
