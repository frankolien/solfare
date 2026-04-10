import 'dart:typed_data';

/// Core wallet entity — the domain representation of a Solana wallet.
/// Contains only what the app needs to know about a wallet.
/// No dependencies on data layer, packages, or frameworks.
class Wallet {
  /// The Solana public address (Base58-encoded public key).
  final String address;

  /// The raw 32-byte public key.
  final Uint8List publicKey;

  /// The 12/24-word mnemonic recovery phrase.
  /// Only available during creation; never persisted in memory long-term.
  final String mnemonic;
  

  const Wallet({
    required this.address,
    required this.publicKey,
    required this.mnemonic,
  });
}
