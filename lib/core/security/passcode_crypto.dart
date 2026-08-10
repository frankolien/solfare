import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// What one passcode derivation produces.
///
/// [authKey] is stored and compared. [wrapKey] never leaves memory — it is
/// what opens the mnemonic. They are separate because a stored value that
/// *is* the encryption key would make reading the keychain equivalent to
/// knowing the passcode, which is the whole thing this exists to prevent.
class PasscodeKeys {
  final Uint8List authKey;
  final Uint8List wrapKey;

  /// The v2 digest these keys correspond to.
  ///
  /// Carried alongside because the caller has to be able to write it *before*
  /// wrapping anything — that is what makes the salt durable, and so the
  /// wrapKey reproducible on the next unlock. Re-deriving it separately would
  /// mint a different salt for a plaintext upgrade and strand the mnemonics.
  final String stored;

  const PasscodeKeys({
    required this.authKey,
    required this.wrapKey,
    required this.stored,
  });
}

/// Passcode hashing + verification using PBKDF2-HMAC-SHA256.
///
/// Stored formats, newest first:
///
///   `v2:<base64 salt>:<iterations>:<base64 authKey>`
///   `v1:<base64 salt>:<iterations>:<base64 hash>`
///   `<plaintext>`  — pre-hashing installs
///
/// v1 and v2 differ only in what the stored 32 bytes are: v1 stores the raw
/// PBKDF2 output, v2 stores one half of an HKDF split of it, so the other
/// half can wrap the mnemonic without ever being written down.
///
/// `hash` and `verify` run on a background isolate via `compute()`. Measured
/// on an M-series Mac: ~340ms per derivation at 100k iterations, and a
/// low-end Android is several times that — far past a dropped frame.
///
/// On the iteration count: see docs/design/passcode-envelope.md. It is
/// bounded by pure-Dart PBKDF2 being the thing standing between an attacker
/// and a six-digit space, and raising it is a separate change.
class PasscodeCrypto {
  static const _iterations = 100000;
  static const _saltBytes = 16;
  static const _hashBytes = 32;
  static const _v1 = 'v1';
  static const _v2 = 'v2';

  // Domain separation for the HKDF split. Changing either string orphans
  // every existing envelope, so they are versioned along with the format.
  static const _authInfo = 'solfare:auth:v2';
  static const _wrapInfo = 'solfare:wrap:v2';

  /// A v2 digest for [passcode], and the keys that go with it.
  static Future<({String stored, PasscodeKeys keys})> create(String passcode) =>
      compute(_createSync, passcode);

  /// The v1 digest. Kept so the existing tests and any caller that only
  /// wants a comparison digest still work.
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
  ///
  /// Null when the passcode is wrong. For a v1 or plaintext digest the
  /// verification uses the old scheme but the keys come back in the new one,
  /// which is what lets a caller upgrade in place.
  static Future<PasscodeKeys?> verifyAndDerive(String passcode, String stored) =>
      compute(_verifyAndDeriveSync, [passcode, stored]);

  // ── isolate entry points ────────────────────────────────────────────────

  static ({String stored, PasscodeKeys keys}) _createSync(String passcode) {
    final keys = _deriveSync(passcode, _randomBytes(_saltBytes), _iterations);
    return (stored: keys.stored, keys: keys);
  }

  static String _hashSync(String passcode) {
    final salt = _randomBytes(_saltBytes);
    final derived = _pbkdf2(passcode, salt, _iterations, _hashBytes);
    return '$_v1:${base64Encode(salt)}:$_iterations:${base64Encode(derived)}';
  }

  // One PBKDF2 pass, split by domain. HKDF-Expand is a couple of HMACs, so
  // this costs the same as the old single-purpose derivation — a second
  // PBKDF2 pass over a different salt would double the unlock time for no
  // added strength.
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
        // Nothing to derive against — mint a fresh salt so the caller can
        // write a real envelope. The passcode is what matters, not the salt
        // this install never had.
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
  //
  // No extract step: the input is already a uniformly distributed 32 bytes
  // from a KDF, which is exactly the case RFC 5869 section 3.3 says extract
  // can be skipped for.
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

  // ── primitives ──────────────────────────────────────────────────────────

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
