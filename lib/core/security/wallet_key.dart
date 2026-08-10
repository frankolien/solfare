import 'package:flutter/foundation.dart';

/// The key that unwraps stored mnemonics, held for the unlocked session.
///
/// Derived from the passcode on a successful unlock and dropped when the app
/// re-locks, so it exists exactly as long as "unlocked" does. One home and
/// one lifetime, rather than being threaded through the blocs that happen to
/// need a mnemonic.
///
/// Holding it in memory rather than asking for the passcode per signature is
/// a deliberate trade, argued in docs/design/passcode-envelope.md: an
/// attacker who can read live process memory has already taken more than the
/// seed, while a passcode prompt on every send, swap and stake is a cost
/// every user pays every time.
class WalletKey {
  WalletKey._();

  static Uint8List? _key;

  /// True while a mnemonic can be unwrapped.
  static bool get isHeld => _key != null;

  static Uint8List? get value => _key;

  static void hold(Uint8List key) => _key = key;

  /// Overwrites the buffer before dropping the reference. Dart cannot
  /// guarantee the bytes are gone — the allocator may have copied them — but
  /// leaving them legible when we could not is a choice, and this is not it.
  static void clear() {
    final key = _key;
    _key = null;
    if (key != null) {
      for (var i = 0; i < key.length; i++) {
        key[i] = 0;
      }
    }
  }

  @visibleForTesting
  static void resetForTest() => clear();
}
