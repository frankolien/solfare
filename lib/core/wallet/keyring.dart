import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/core/error/exception.dart';

/// Single source of truth for secret → keypair derivation.
///
/// A secret is a BIP-39 phrase or, prefixed with [pkPrefix], a raw key.
class Keyring {
  Keyring._();

  // Do NOT zero `priv` — Ed25519HDKeyPair stores it by reference, so zeroing
  // here corrupts the signing key and every tx fails verification.
  static Future<solana.Ed25519HDKeyPair> keyPairFor(
    String mnemonic,
  ) async {
    final priv = await _privateKeyBytes(mnemonic);
    return solana.Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: priv);
  }

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

  /// Marks a stored secret that is a raw key rather than a phrase.
  ///
  /// A discriminated string rather than a new column: the field already
  /// carries the envelope's `v2:` prefix, so this is the shape it is in, and a
  /// schema change would mean migrating every existing entry to gain nothing.
  static const pkPrefix = 'pk:';

  /// True when [secret] is a raw key, which has no recovery phrase to show.
  static bool isPrivateKey(String secret) => secret.startsWith(pkPrefix);

  /// Normalise typed or pasted input into something storable, or null when it
  /// is neither a phrase nor a key.
  ///
  /// Accepts the two shapes other wallets export: base58, and the JSON array
  /// of bytes that `solana-keygen` writes.
  static String? parseSecret(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final phrase = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (bip39.validateMnemonic(phrase)) return phrase;

    final bytes = _keyBytes(text);
    if (bytes == null) return null;
    return '$pkPrefix${base58.encode(bytes)}';
  }

  /// The 32 secret bytes in [raw], however it was encoded.
  static Uint8List? _keyBytes(String raw) {
    final text = raw.trim();

    if (text.startsWith('[')) {
      try {
        final list = jsonDecode(text);
        if (list is! List) return null;
        final ints = <int>[];
        for (final v in list) {
          if (v is! num || v < 0 || v > 255) return null;
          ints.add(v.toInt());
        }
        return _secretOf(Uint8List.fromList(ints));
      } catch (_) {
        return null;
      }
    }

    // A phrase is base58-decodable in principle, so anything with a space is
    // not a key however it decodes.
    if (text.contains(RegExp(r'\s'))) return null;
    try {
      return _secretOf(Uint8List.fromList(base58.decode(text)));
    } catch (_) {
      return null;
    }
  }

  // Exports carry either the 64-byte keypair (secret followed by public) or
  // the 32-byte secret alone. Anything else is not a key.
  static Uint8List? _secretOf(Uint8List bytes) {
    if (bytes.length == 64) return Uint8List.fromList(bytes.sublist(0, 32));
    if (bytes.length == 32) return bytes;
    return null;
  }

  static Future<Uint8List> _privateKeyBytes(String secret) async {
    if (isPrivateKey(secret)) {
      final bytes = _keyBytes(secret.substring(pkPrefix.length));
      if (bytes == null) {
        throw const KeyDerivationException('Invalid private key');
      }
      return bytes;
    }

    final mnemonic = secret;
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
