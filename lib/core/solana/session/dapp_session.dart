import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:pinenacl/x25519.dart' as nacl;

/// An encrypted channel with one dapp.
///
/// Each connection gets its own keypair, so revoking one dapp cannot affect
/// another and a leaked session key is worth exactly one dapp's traffic. The
/// construction is Curve25519 + XSalsa20 + Poly1305 — the same one the
/// established wallet deeplink schemes use, so a dapp written against them
/// needs no new cryptography to talk to Solfare.
class DappSession {
  /// Host of the dapp's https origin. The only identity worth trusting: a
  /// dapp picks its own name, it does not pick its domain.
  final String origin;

  /// The dapp's x25519 public key, base58. Also the session's lookup key.
  final String dappPublicKey;

  /// Our x25519 private key for this dapp, base58. Never leaves the device.
  final String sessionPrivateKey;

  /// Wallet the user connected. A session is bound to one account.
  final String walletAddress;

  /// Opaque token echoed by the dapp on later requests.
  final String sessionToken;

  final DateTime createdAt;
  final DateTime lastUsedAt;

  const DappSession({
    required this.origin,
    required this.dappPublicKey,
    required this.sessionPrivateKey,
    required this.walletAddress,
    required this.sessionToken,
    required this.createdAt,
    required this.lastUsedAt,
  });

  /// Sessions go stale rather than living forever. A dapp the user has not
  /// opened in a month should have to ask again.
  static const Duration maxIdle = Duration(days: 30);

  bool isExpiredAt(DateTime now) => now.difference(lastUsedAt) > maxIdle;

  DappSession touched(DateTime now) => DappSession(
        origin: origin,
        dappPublicKey: dappPublicKey,
        sessionPrivateKey: sessionPrivateKey,
        walletAddress: walletAddress,
        sessionToken: sessionToken,
        createdAt: createdAt,
        lastUsedAt: now,
      );

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'dappPublicKey': dappPublicKey,
        'sessionPrivateKey': sessionPrivateKey,
        'walletAddress': walletAddress,
        'sessionToken': sessionToken,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory DappSession.fromJson(Map<String, dynamic> json) => DappSession(
        origin: json['origin'] as String,
        dappPublicKey: json['dappPublicKey'] as String,
        sessionPrivateKey: json['sessionPrivateKey'] as String,
        walletAddress: json['walletAddress'] as String,
        sessionToken: json['sessionToken'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      );
}

/// Sealing and opening payloads for a session.
///
/// Kept apart from [DappSession] so the key handling has one home and the
/// session stays a plain record.
class SessionCrypto {
  const SessionCrypto._();

  /// A fresh x25519 keypair, one per connection.
  static ({String privateKey, String publicKey}) generateKeyPair() {
    final private = nacl.PrivateKey.generate();
    return (
      privateKey: base58.encode(Uint8List.fromList(private.toList())),
      publicKey: base58.encode(Uint8List.fromList(private.publicKey.toList())),
    );
  }

  /// An opaque session token for the dapp to echo back. 32 bytes from the
  /// same CSPRNG the keys come from.
  static String randomToken() => base58.encode(
        Uint8List.fromList(nacl.PrivateKey.generate().publicKey.toList()),
      );

  static nacl.Box _box({required String privateKey, required String theirPublicKey}) => nacl.Box(
        myPrivateKey: nacl.PrivateKey(base58.decode(privateKey)),
        theirPublicKey: nacl.PublicKey(base58.decode(theirPublicKey)),
      );

  /// Encrypt [payload] for the dapp. Returns the nonce and ciphertext, both
  /// base58, since that is what travels in a deeplink.
  static ({String nonce, String payload}) seal({
    required Map<String, dynamic> payload,
    required String sessionPrivateKey,
    required String dappPublicKey,
  }) {
    final box = _box(privateKey: sessionPrivateKey, theirPublicKey: dappPublicKey);
    final encrypted = box.encrypt(
      Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    );
    return (
      nonce: base58.encode(Uint8List.fromList(encrypted.nonce.toList())),
      payload: base58.encode(Uint8List.fromList(encrypted.cipherText.toList())),
    );
  }

  /// Decrypt a payload from the dapp.
  ///
  /// Throws [SessionCryptoException] on any failure. Callers must not report
  /// which part failed: telling a caller apart "wrong key" from "bad
  /// ciphertext" hands them an oracle.
  static Map<String, dynamic> open({
    required String nonce,
    required String payload,
    required String sessionPrivateKey,
    required String dappPublicKey,
  }) {
    try {
      final box = _box(privateKey: sessionPrivateKey, theirPublicKey: dappPublicKey);
      final plain = box.decrypt(
        nacl.ByteList(base58.decode(payload)),
        nonce: base58.decode(nonce),
      );
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map<String, dynamic>) {
        throw const SessionCryptoException();
      }
      return decoded;
    } catch (_) {
      throw const SessionCryptoException();
    }
  }
}

/// Deliberately carries no detail. The dapp learns that it failed, nothing
/// about why.
class SessionCryptoException implements Exception {
  const SessionCryptoException();

  @override
  String toString() => 'Could not decrypt the request.';
}
