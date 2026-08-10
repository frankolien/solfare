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

  /// Where replies go, fixed at connect time.
  ///
  /// It used to be read off each incoming request instead. That let a
  /// captured deeplink be resent with the callback swapped: the payload
  /// decrypts (same key, same nonce, same ciphertext), the sheet shows the
  /// real dapp and the real preview, and the signed transaction is delivered
  /// to whoever asked last.
  final String redirectLink;

  /// Nonces already accepted from this dapp, newest last.
  ///
  /// Sealed payloads are replayable without this: the same ciphertext opens
  /// every time. Bounded, because a session is long-lived and an unbounded
  /// list is a way to fill the keychain.
  final List<String> seenNonces;

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
    this.redirectLink = '',
    this.seenNonces = const [],
  });

  /// Sessions go stale rather than living forever. A dapp the user has not
  /// opened in a month should have to ask again.
  static const Duration maxIdle = Duration(days: 30);

  /// And an absolute ceiling regardless of use. Without one, a dapp that
  /// pings monthly holds its grant forever, which is not what "I connected
  /// to this once" means.
  static const Duration maxLifetime = Duration(days: 90);

  /// How many nonces to remember. Generous next to any real request rate,
  /// and small enough that the stored session stays a few kilobytes.
  static const int nonceMemory = 256;

  bool isExpiredAt(DateTime now) =>
      now.difference(lastUsedAt) > maxIdle ||
      now.difference(createdAt) > maxLifetime;

  bool hasSeen(String nonce) => seenNonces.contains(nonce);

  /// Records [nonce] and marks the session used, dropping the oldest nonces
  /// once the window is full.
  DappSession accepting(String nonce, DateTime now) {
    final next = [...seenNonces, nonce];
    return _copy(
      lastUsedAt: now,
      seenNonces:
          next.length <= nonceMemory ? next : next.sublist(next.length - nonceMemory),
    );
  }

  DappSession touched(DateTime now) => _copy(lastUsedAt: now);

  DappSession _copy({DateTime? lastUsedAt, List<String>? seenNonces}) => DappSession(
        origin: origin,
        dappPublicKey: dappPublicKey,
        sessionPrivateKey: sessionPrivateKey,
        walletAddress: walletAddress,
        sessionToken: sessionToken,
        redirectLink: redirectLink,
        seenNonces: seenNonces ?? this.seenNonces,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  // UTC on the way out. toIso8601String() on a local DateTime emits no
  // offset and parses back as local, so a session written in UTC+2 and read
  // in UTC-7 shifted nine hours — living that much too long or dying that
  // much early, depending on which way the user travelled.
  Map<String, dynamic> toJson() => {
        'origin': origin,
        'dappPublicKey': dappPublicKey,
        'sessionPrivateKey': sessionPrivateKey,
        'walletAddress': walletAddress,
        'sessionToken': sessionToken,
        'redirectLink': redirectLink,
        'seenNonces': seenNonces,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
      };

  factory DappSession.fromJson(Map<String, dynamic> json) => DappSession(
        origin: json['origin'] as String,
        dappPublicKey: json['dappPublicKey'] as String,
        sessionPrivateKey: json['sessionPrivateKey'] as String,
        walletAddress: json['walletAddress'] as String,
        sessionToken: json['sessionToken'] as String,
        redirectLink: json['redirectLink'] as String? ?? '',
        seenNonces: [
          for (final n in (json['seenNonces'] as List? ?? const []))
            if (n is String) n,
        ],
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String).toUtc(),
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
