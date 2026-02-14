/// Solana BIP-44 derivation path constants.
class SolanaPath {
  SolanaPath._();

  /// Default derivation path for Solana wallets.
  /// m/44' = BIP-44 purpose
  /// /501' = Solana coin type
  /// /0'   = account index
  /// /0'   = change
  static const String defaultPath = "m/44'/501'/0'/0'";
}
