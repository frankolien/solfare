import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  Uint8List key(int fill) => Uint8List.fromList(List<int>.filled(32, fill));

  test('a wrapped mnemonic round-trips', () {
    final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
    expect(MnemonicEnvelope.unwrap(wrapped, key(7)), mnemonic);
  });

  test('the wrapped form does not contain the mnemonic', () {
    final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
    expect(wrapped.contains('abandon'), isFalse);
    expect(wrapped.contains('about'), isFalse);
  });

  test('every wrap uses a fresh nonce', () {
    // Same key, same plaintext, different ciphertext. A reused nonce with
    // XSalsa20 leaks the XOR of two plaintexts.
    final a = MnemonicEnvelope.wrap(mnemonic, key(7));
    final b = MnemonicEnvelope.wrap(mnemonic, key(7));
    expect(a, isNot(b));
    expect(MnemonicEnvelope.unwrap(b, key(7)), mnemonic);
  });

  test('the wrong key fails closed', () {
    final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
    expect(
      () => MnemonicEnvelope.unwrap(wrapped, key(8)),
      throwsA(isA<MnemonicLockedException>()),
    );
  });

  test('a tampered ciphertext fails closed rather than yielding words', () {
    // The reason this is authenticated encryption: any 12 words BIP-39
    // accepts is a valid wallet, just not the user's. Garbage out is worse
    // than an error here.
    final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
    final parts = wrapped.split(':');
    final bytes = base64Decode(parts[2]);
    bytes[0] ^= 0xFF;
    final tampered = '${parts[0]}:${parts[1]}:${base64Encode(bytes)}';

    expect(
      () => MnemonicEnvelope.unwrap(tampered, key(7)),
      throwsA(isA<MnemonicLockedException>()),
    );
  });

  test('a tampered nonce fails closed', () {
    final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
    final parts = wrapped.split(':');
    final nonce = base64Decode(parts[1]);
    nonce[0] ^= 0xFF;
    final tampered = '${parts[0]}:${base64Encode(nonce)}:${parts[2]}';

    expect(
      () => MnemonicEnvelope.unwrap(tampered, key(7)),
      throwsA(isA<MnemonicLockedException>()),
    );
  });

  group('plaintext', () {
    test('passes through untouched, with or without a key', () {
      // Pre-migration installs. Refusing these would lock every existing
      // user out of their own wallet.
      expect(MnemonicEnvelope.unwrap(mnemonic, null), mnemonic);
      expect(MnemonicEnvelope.unwrap(mnemonic, key(7)), mnemonic);
    });

    test('is not mistaken for a wrapped one', () {
      expect(MnemonicEnvelope.isWrapped(mnemonic), isFalse);
      expect(MnemonicEnvelope.isWrapped(MnemonicEnvelope.wrap(mnemonic, key(7))), isTrue);
    });
  });

  group('locked', () {
    test('opening without a key is locked, not empty', () {
      // The distinction the whole design turns on: an empty answer is
      // indistinguishable from "no wallet", and that answer overwrites seeds.
      final wrapped = MnemonicEnvelope.wrap(mnemonic, key(7));
      try {
        MnemonicEnvelope.unwrap(wrapped, null);
        fail('should have thrown');
      } on MnemonicLockedException catch (e) {
        expect(e.locked, isTrue);
      }
    });

    test('a corrupt entry is reported as corrupt, not as locked', () {
      try {
        MnemonicEnvelope.unwrap('v2:only-two-parts', key(7));
        fail('should have thrown');
      } on MnemonicLockedException catch (e) {
        expect(e.locked, isFalse,
            reason: 'a passcode will not fix this, so do not ask for one');
      }
    });
  });
}
