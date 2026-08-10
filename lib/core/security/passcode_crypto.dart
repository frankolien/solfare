import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// What one passcode derivation produces.
class PasscodeKeys {
  final Uint8List authKey;
  final Uint8List wrapKey;

  /// The v2 digest these keys correspond to.
  final String stored;

  const PasscodeKeys({
    required this.authKey,
    required this.wrapKey,
    required this.stored,
  });
}

/// Passcode hashing + verification using PBKDF2-HMAC-SHA256.
class PasscodeCrypto {
  static const _iterations = 100000;
  static const _saltBytes = 16;
  static const _hashBytes = 32;
  static const _v1 = 'v1';
  static const _v2 = 'v2';

  // Domain separation for the HKDF split.
  static const _authInfo = 'solfare:auth:v2';
  static const _wrapInfo = 'solfare:wrap:v2';

  /// A v2 digest for [passcode], and the keys that go with it.
  static Future<({String stored, PasscodeKeys keys})> create(String passcode) =>
      compute(_createSync, passcode);

  /// The v1 digest.
  static Future<String> hash(String passcode) => compute(_hashSync, passcode);

  static bool isLegacyPlaintext(String stored) =>
      !stored.startsWith('$_v1:') && !stored.startsWith('$_v2:');

  /// True when [stored] is the older digest, so the caller knows to upgrade.
  static bool needsUpgrade(String stored) => !stored.startsWith('$_v2:');

  static Future<bool> verify(String passcode, String stored) {
    // Legacy plaintext compare is cheap — no need to ship to an isolate.
    if (isLegacyPlaintext(stored)) {
      return Future.value(_constantTimeEqualsString(passcode, stored));
    }
    return compute(_verifySync, [passcode, stored]);
  }

  /// Verifies and, on success, returns the keys derived along the way.
  static Future<PasscodeKeys?> verifyAndDerive(String passcode, String stored) =>
      compute(_verifyAndDeriveSync, [passcode, stored]);

  static ({String stored, PasscodeKeys keys}) _createSync(String passcode) {
    final keys = _deriveSync(passcode, _randomBytes(_saltBytes), _iterations);
    return (stored: keys.stored, keys: keys);
  }

  static String _hashSync(String passcode) {
    final salt = _randomBytes(_saltBytes);
    final derived = _pbkdf2(passcode, salt, _iterations, _hashBytes);
    return '$_v1:${base64Encode(salt)}:$_iterations:${base64Encode(derived)}';
  }

  // One PBKDF2 pass, split by domain.
  static PasscodeKeys _deriveSync(String passcode, List<int> salt, int iterations) {
    final master = _pbkdf2(passcode, salt, iterations, _hashBytes);
    final authKey = _hkdfExpand(master, _authInfo, _hashBytes);
    return PasscodeKeys(
      authKey: authKey,
      wrapKey: _hkdfExpand(master, _wrapInfo, _hashBytes),
      stored: '$_v2:${base64Encode(salt)}:$iterations:${base64Encode(authKey)}',
    );
  }

  static bool _verifySync(List<String> args) =>
      _verifyAndDeriveSync(args) != null;

  static PasscodeKeys? _verifyAndDeriveSync(List<String> args) {
    try {
      final passcode = args[0];
      final stored = args[1];

      if (isLegacyPlaintext(stored)) {
        if (!_constantTimeEqualsString(passcode, stored)) return null;
        // Nothing to derive against — mint a fresh salt so the caller can write
        // a real envelope.
        return _deriveSync(passcode, _randomBytes(_saltBytes), _iterations);
      }

      final parts = stored.split(':');
      if (parts.length != 4) return null;
      final version = parts[0];
      final salt = base64Decode(parts[1]);
      final iterations = int.parse(parts[2]);
      final expected = base64Decode(parts[3]);

      if (version == _v1) {
        // v1 stored the raw PBKDF2 output, so that is what has to match.
        final derived = _pbkdf2(passcode, salt, iterations, expected.length);
        if (!_constantTimeEquals(derived, expected)) return null;
        return _deriveSync(passcode, salt, iterations);
      }

      if (version == _v2) {
        final keys = _deriveSync(passcode, salt, iterations);
        if (!_constantTimeEquals(keys.authKey, expected)) return null;
        return keys;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // HKDF-Expand (RFC 5869) with the PBKDF2 output as the pseudorandom key.
  static Uint8List _hkdfExpand(List<int> prk, String info, int length) {
    final hmac = Hmac(sha256, prk);
    final infoBytes = utf8.encode(info);
    final out = BytesBuilder();
    var previous = <int>[];
    for (var counter = 1; out.length < length; counter++) {
      previous = hmac.convert([...previous, ...infoBytes, counter]).bytes;
      out.add(previous);
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static bool _constantTimeEqualsString(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  // PBKDF2-HMAC-SHA256 built on top of the `crypto` package's Hmac.
  static Uint8List _pbkdf2(
    String password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hLen = 32;
    final blocks = (length / hLen).ceil();
    final out = BytesBuilder();
    for (var i = 1; i <= blocks; i++) {
      final block = _pbkdf2Block(hmac, salt, iterations, i);
      out.add(block);
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static List<int> _pbkdf2Block(Hmac hmac, List<int> salt, int iterations, int blockIndex) {
    final saltWithIndex = <int>[
      ...salt,
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];
    List<int> u = hmac.convert(saltWithIndex).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
