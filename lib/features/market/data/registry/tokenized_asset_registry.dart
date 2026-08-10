import 'package:solfare/features/market/domain/entities/market_category.dart';

/// Mints that Jupiter serves but does not shelve.
///
/// `/tokens/v2/tag` accepts only `verified` and `lst`, and the tags carried by
/// the tokens themselves disagree with each other about what a commodity is —
/// three gold tokens come back tagged `stocks`, `commodities` and neither. So
/// the split the user sees is made here.
///
/// This file ships mints, shelves and the odd display name. Prices, decimals
/// and the API's own naming are hydrated on every load, because a bundled
/// price is a stale price.
class TokenizedAssetRegistry {
  const TokenizedAssetRegistry._();

  /// A registry entry is a claim about the world made when this file was
  /// written. On load the claim is rechecked against these tags, and an entry
  /// that no longer carries one is dropped rather than left on a shelf it has
  /// stopped belonging to. Only shelves of tokenised real-world assets are
  /// checked this way — see [MarketCategory.requiresRwaTag].
  static const Set<String> rwaTags = {
    'stocks',
    'equities',
    'commodities',
    'rwa',
    'xstocks',
    'ondo',
    'prestocks',
    'backpack',
  };

  /// Liquidity below which every entry here was rejected when this file was
  /// written. Kept as documentation of the bar, not enforced at runtime — the
  /// runtime guard only drops what has fallen to nothing, since any live
  /// threshold would be a number nobody agreed on.
  static const double bundledLiquidityFloor = 1000;

  static const List<String> _majorCrypto = [
    'So11111111111111111111111111111111111111112', // SOL    Wrapped SOL
    'cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij', // cbBTC  Coinbase Wrapped BTC
    '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs', // ETH   Ether (Portal)
    '3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh', // WBTC  Wrapped BTC (Portal)
    'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN', // JUP    Jupiter
    'jtojtomepa8beP8AuQc6eXt5FriJwfFMwQx2v2f9mCL', // JTO    Jito
  ];

  // Companies. One issuer per name, picked by liquidity — SpaceX alone is
  // served by five, and liquidity is what decides whether a purchase fills
  // at the price on the card.
  static const List<String> _stocks = [
    'Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh', // NVDAx      NVIDIA
    'XsueG8BtpquVJX9LVLLEGuViXUungE6WmK5YZ3p3bd1', // CRCLx      Circle
    'XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB', // TSLAx      Tesla
    'Pren1FvFX6J3E4kXhJuCiAD5aDmGEb7qJRncwA8Lkhw', // ANTHROPIC  Anthropic (pre-IPO)
    'SPCXxcqXj6e5dJDVNovHN8744zkbhM2bYudU45BimGb', // SPCX       SpaceX (pre-IPO)
    'XsP7xzNPvEHS1m6qfanPUGjNmdnmsLKEoNAnHjdxxyZ', // MSTRx      MicroStrategy
    'Xs7ZdzSHLU9ftNJsii5fCeJhoRWSC32SQGzGQtePxNu', // COINx      Coinbase
    'XsvNBAYkrDRNhA7wPHQfX3ZUXZyZLdnCQDfHZ56bzpg', // HOODx      Robinhood
    'XsCPL9dNWBMvFtTmwcCA5v3xWPSMEBCszbQdiLLq6aN', // GOOGLx     Alphabet
    'XspzcW1PRtgf6Wj92HCiZdjzKCyFekVD8P5Ueh3dRMX', // MSFTx      Microsoft
    'PreweJYECqtQwBtpxHL171nL2K6umo692gTm7Q3rpgF', // OPENAI     OpenAI (pre-IPO)
    'Xs3eBt7uRfJX8QUs4suhyU8p2M6DoUDrJyWBa8LLZsg', // AMZNx      Amazon
    'XsoBhf2ufR8fTyNSjqfU71DYGaE6Z3SUGAidpzriAA4', // PLTRx      Palantir
    'XsbEhLAtcf6HdfpFZ5xEMdqW8nfAvcsP5bdudRLJzJp', // AAPLx      Apple
    'XsqE9cRRpzxcGKDXj1BJ7Xmg4GRhZoyY1KpmGSxAWT2', // MCDx       McDonald's
    'XsgSaSvNSqLTtFuyWPBhK9196Xb9Bbdyjj4fH3cPJGo', // AVGOx      Broadcom
    'Xsa62P5mvPszXL1krVUnU5ar38bBSVcWAB6fmPCo5Zu', // METAx      Meta
    'Xs6B6zawENwAbWVi7w92rjazLuAr5Az59qgWKcNb45x', // BRK.Bx     Berkshire Hathaway
    'XsjFwUPiLofddX5cWFHW35GCbXcSu1BCUGfxoQAQjeL', // ORCLx      Oracle
    'XsXcJ6GZ9kVnjqGsjBnktRcuwMBmvKWh8S93RefZ1rF', // AMDx       AMD
  ];

  // Funds. A gold ETF tracks a fund's price, not the metal's, which is why
  // it sits here rather than under commodities.
  static const List<String> _etfs = [
    'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W', // SPYx   S&P 500
    'Xs8S1uUs1zvS2p7iwtsG3b6fkhpvmwz4GYU3gWAmWHZ', // QQQx   Nasdaq 100
    'Xsv9hRk1z5ystj9MhnA7Lq4vjSsLwzL2nxrwmwtD3re', // GLDx   SPDR Gold Shares
    'iy11ytbSGcUnrjE6Lfv78TFqxKyUESfku1FugS9ondo', // SLVon  iShares Silver Trust
    'hWfiw4mcxT8rnNFkk6fsCQSxoxgZ9yVhB6tyeVcondo', // GLDon  SPDR Gold Shares (Ondo)
    'XsjQP3iMAaQ3kQScQKthQpx9ALRbjKAjQtHg6TFomoc', // TQQQx  Nasdaq 100 3x
  ];

  // The metal itself. Platinum is not here: both issuers show no liquidity
  // and an order against one answers "Quote not available from market
  // maker", so listing it would only be a card that cannot be bought.
  static const List<String> _commodities = [
    'AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P', // XAUt0  Tether Gold
    '5GgRAEmv8ZxF2PR5hY72Qs5x1bnQ6UK2RbTPoqJ3wSwW', // PAXG   PAX Gold
  ];

  // Names for the handful of mints where stripping the issuer still leaves
  // something nobody says out loud. Everything else derives its display name
  // from what the API returns.
  static const Map<String, String> _displayNames = {
    'So11111111111111111111111111111111111111112': 'Solana',
    'cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij': 'Bitcoin',
    '3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh': 'Bitcoin (Portal)',
    '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs': 'Ethereum',
    'jtojtomepa8beP8AuQc6eXt5FriJwfFMwQx2v2f9mCL': 'Jito',
    'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W': 'S&P 500',
    'Xs8S1uUs1zvS2p7iwtsG3b6fkhpvmwz4GYU3gWAmWHZ': 'Nasdaq 100',
    'XsjQP3iMAaQ3kQScQKthQpx9ALRbjKAjQtHg6TFomoc': 'Nasdaq 100 3x',
    'Xsv9hRk1z5ystj9MhnA7Lq4vjSsLwzL2nxrwmwtD3re': 'SPDR Gold Shares',
    'hWfiw4mcxT8rnNFkk6fsCQSxoxgZ9yVhB6tyeVcondo': 'SPDR Gold Shares (Ondo)',
    'iy11ytbSGcUnrjE6Lfv78TFqxKyUESfku1FugS9ondo': 'iShares Silver Trust',
    'AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P': 'Gold',
    '5GgRAEmv8ZxF2PR5hY72Qs5x1bnQ6UK2RbTPoqJ3wSwW': 'Gold (Paxos)',
  };

  // Suffixes that say who issued the token rather than what it is. A card
  // the size of a thumbnail has no room for the issuer, and the detail
  // screen still shows the full name.
  static const List<String> _issuerSuffixes = [
    ' xStock',
    ' PreStocks',
    ' - Backpack Securities',
    ' (Ondo Tokenized)',
    ' (Ondo Token)',
  ];

  static List<String> mintsFor(MarketCategory category) => switch (category) {
        MarketCategory.majorCrypto => _majorCrypto,
        MarketCategory.stocks => _stocks,
        MarketCategory.etfs => _etfs,
        MarketCategory.commodities => _commodities,
        MarketCategory.tokens => const [],
      };

  static MarketCategory? categoryOf(String mint) {
    for (final category in MarketCategory.values) {
      if (mintsFor(category).contains(mint)) return category;
    }
    return null;
  }

  /// What to put on a card. Falls back to the API name with the issuer
  /// stripped, so a mint added later needs no entry here to read properly.
  static String displayName(String mint, String apiName) {
    final override = _displayNames[mint];
    if (override != null) return override;

    var name = apiName;
    for (final suffix in _issuerSuffixes) {
      if (name.toLowerCase().endsWith(suffix.toLowerCase())) {
        name = name.substring(0, name.length - suffix.length);
        break;
      }
    }
    return name.trim().isEmpty ? apiName : name.trim();
  }

  /// Whether [tags] still support shelving a mint as a real-world asset.
  static bool tagsSupportRwa(Iterable<String> tags) => tags.any(rwaTags.contains);
}
