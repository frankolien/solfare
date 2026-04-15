import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Passcode hashing + verification using PBKDF2-HMAC-SHA256.
///
/// Stored format: `v1:<base64 salt>:<iterations>:<base64 hash>` so that we can
/// change iterations or algorithm later without breaking existing users.
class PasscodeCrypto {
  static const _iterations = 100000;
  static const _saltBytes = 16;
  static const _hashBytes = 32;
  static const _version = 'v1';

  /// Returns a serialized hash string safe to store in secure storage.
  static String hash(String passcode) {
    final salt = _randomBytes(_saltBytes);
    final derived = _pbkdf2(passcode, salt, _iterations, _hashBytes);
    return '$_version:${base64Encode(salt)}:$_iterations:${base64Encode(derived)}';
  }

  /// Returns true if [stored] looks like a legacy plaintext passcode from
  /// before hashing was introduced. Used so existing installs keep working.
  static bool isLegacyPlaintext(String stored) => !stored.startsWith('$_version:');

  /// Constant-time verification against a stored hash string. Also accepts
  /// legacy plaintext values so pre-hashing installs keep working; the caller
  /// is expected to re-save the passcode as a hash after a successful verify.
  static bool verify(String passcode, String stored) {
    try {
      if (isLegacyPlaintext(stored)) {
        return _constantTimeEqualsString(passcode, stored);
      }
      final parts = stored.split(':');
      if (parts.length != 4 || parts[0] != _version) return false;
      final salt = base64Decode(parts[1]);
      final iterations = int.parse(parts[2]);
      final expected = base64Decode(parts[3]);
      final derived = _pbkdf2(passcode, salt, iterations, expected.length);
      return _constantTimeEquals(derived, expected);
    } catch (_) {
      return false;
    }
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

  /// PBKDF2-HMAC-SHA256 implementation using the `crypto` package's Hmac.
  static Uint8List _pbkdf2(
    String password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final hLen = 32;
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
