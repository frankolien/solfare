import 'dart:convert';
import 'dart:typed_data';

import 'package:pinenacl/x25519.dart' as nacl;

/// A mnemonic that could not be opened.
///
/// Thrown for both "no key held" and "the ciphertext did not authenticate",
/// which are different problems: the first is a locked app and the second is
/// a tampered or corrupt store. [locked] tells them apart for the caller
/// that has to choose between "unlock to continue" and "something is wrong".
class MnemonicLockedException implements Exception {
  final String message;
  final bool locked;

  const MnemonicLockedException(this.message, {this.locked = true});

  @override
  String toString() => message;
}

/// Wraps a mnemonic with a key derived from the passcode.
///
/// XSalsa20-Poly1305 via `SecretBox`, which the dapp session code already
/// uses — one authenticated-encryption construction in the app rather than
/// two to review. Authenticated matters here: a tampered blob has to fail to
/// open rather than yield bytes that get handed to BIP-39, where an
/// arbitrary 12 words is a perfectly valid wallet that is not the user's.
///
/// Stored form:
///
///   `v2:<base64 nonce>:<base64 ciphertext>`
///
/// Anything without the prefix is a pre-migration plaintext mnemonic and is
/// returned as-is, the same way `PasscodeCrypto.isLegacyPlaintext` reasons
/// about the older digest.
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
  ///
  /// [key] may be null only for plaintext — asking to open a wrapped
  /// mnemonic without one is the locked case, not an empty result, because
  /// an empty result is indistinguishable from "no wallet" and that is the
  /// answer that gets a seed overwritten.
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
      // Either the wrong key or a tampered blob, and the difference is not
      // ours to report — both mean this mnemonic is not available, and
      // saying which would answer a question nobody friendly is asking.
      throw const MnemonicLockedException(
        'This wallet entry could not be read.',
        locked: false,
      );
    }
  }
}
