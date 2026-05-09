import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/core/error/exception.dart';

/// Single source of truth for mnemonic → keypair derivation.
///
/// Every callsite that needs to sign on behalf of the user (send, swap,
/// stake, export) must go through here so the BIP-44 path, public-key
/// shape, and intermediate-buffer scrubbing live in exactly one place.
class Keyring {
  Keyring._();

  /// Derive a Solana signing keypair from the given BIP-39 mnemonic.
  /// The seed and intermediate private-key bytes are zeroed before return.
  static Future<solana.Ed25519HDKeyPair> keyPairFromMnemonic(
    String mnemonic,
  ) async {
    final priv = await _privateKeyBytes(mnemonic);
    try {
      return solana.Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: priv);
    } finally {
      _zero(priv);
    }
  }

  /// Derive the raw 32-byte private key. The caller owns the buffer and
  /// is responsible for zeroing it. Used by the export-key screen, which
  /// holds the bytes for the duration the user has the screen open.
  static Future<Uint8List> privateKeyBytes(String mnemonic) =>
      _privateKeyBytes(mnemonic);

  /// Derive the public-key bytes (32 bytes) and base58 address.
  static Future<({Uint8List publicKey, String address})> publicKeyFor(
    String mnemonic,
  ) async {
    final priv = await _privateKeyBytes(mnemonic);
    try {
      final raw = await ED25519_HD_KEY.getPublicKey(priv);
      // ed25519_hd_key prepends a 0x00 byte by default; strip it.
      final pub = Uint8List.fromList(raw.length == 33 ? raw.sublist(1) : raw);
      return (publicKey: pub, address: base58.encode(pub));
    } finally {
      _zero(priv);
    }
  }

  static Future<Uint8List> _privateKeyBytes(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw const KeyDerivationException('Invalid mnemonic phrase');
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    try {
      final keyData = await ED25519_HD_KEY.derivePath(
        SolanaPath.defaultPath,
        seed,
      );
      return Uint8List.fromList(keyData.key);
    } finally {
      _zero(seed);
    }
  }

  static void _zero(List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}
