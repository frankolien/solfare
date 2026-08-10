import 'dart:convert';
import 'dart:typed_data';

import 'package:pinenacl/x25519.dart' as nacl;

/// A mnemonic that could not be opened.
class MnemonicLockedException implements Exception {
  final String message;
  final bool locked;

  const MnemonicLockedException(this.message, {this.locked = true});

  @override
  String toString() => message;
}

/// Wraps a mnemonic with a key derived from the passcode.
class MnemonicEnvelope {
  const MnemonicEnvelope._();

  static const _version = 'v2';

  static bool isWrapped(String stored) => stored.startsWith('$_version:');

  static String wrap(String mnemonic, Uint8List key) {
    final box = nacl.SecretBox(key);
    final sealed = box.encrypt(Uint8List.fromList(utf8.encode(mnemonic)));
    final nonce = Uint8List.fromList(sealed.nonce.toList());
    final cipherText = Uint8List.fromList(sealed.cipherText.toList());
    return '$_version:${base64Encode(nonce)}:${base64Encode(cipherText)}';
  }

  /// Opens [stored], or returns it unchanged when it is plaintext.
  static String unwrap(String stored, Uint8List? key) {
    if (!isWrapped(stored)) return stored;

    if (key == null) {
      throw const MnemonicLockedException(
        'The wallet is locked. Enter your passcode to continue.',
      );
    }

    final parts = stored.split(':');
    if (parts.length != 3) {
      throw const MnemonicLockedException(
        'This wallet entry could not be read.',
        locked: false,
      );
    }

    try {
      final nonce = base64Decode(parts[1]);
      final cipherText = base64Decode(parts[2]);
      final plain = nacl.SecretBox(key).decrypt(
        nacl.ByteList(cipherText),
        nonce: nonce,
      );
      return utf8.decode(plain);
    } catch (_) {
      throw const MnemonicLockedException(
        'This wallet entry could not be read.',
        locked: false,
      );
    }
  }
}
