import 'package:flutter/foundation.dart';

/// The key that unwraps stored mnemonics, held for the unlocked session.
class WalletKey {
  WalletKey._();

  static Uint8List? _key;

  /// True while a mnemonic can be unwrapped.
  static bool get isHeld => _key != null;

  static Uint8List? get value => _key;

  static void hold(Uint8List key) => _key = key;

  /// Overwrites the buffer before dropping the reference.
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
