import 'dart:typed_data';

/// Core wallet entity — the domain representation of a Solana wallet.
class Wallet {
  /// The Solana public address (Base58-encoded public key).
  final String address;

  /// The raw 32-byte public key.
  final Uint8List publicKey;

  /// The 12/24-word mnemonic recovery phrase.
  final String mnemonic;
  
  const Wallet({
    required this.address,
    required this.publicKey,
    required this.mnemonic,
  });
}
