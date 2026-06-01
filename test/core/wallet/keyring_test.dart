import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/core/wallet/keyring.dart';

void main() {
  // Standard BIP-39 12-word test mnemonic (RFC sample, never used in production).
  const testMnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  group('Keyring', () {
    test('derivation is deterministic for the same mnemonic', () async {
      final a = await Keyring.publicKeyFor(testMnemonic);
      final b = await Keyring.publicKeyFor(testMnemonic);
      expect(a.address, equals(b.address));
      expect(a.publicKey, equals(b.publicKey));
    });

    test('different mnemonics derive different addresses', () async {
      const other = 'legal winner thank year wave sausage worth useful '
          'legal winner thank yellow';
      final a = await Keyring.publicKeyFor(testMnemonic);
      final b = await Keyring.publicKeyFor(other);
      expect(a.address, isNot(equals(b.address)));
    });

    test('publicKey is exactly 32 bytes (Solana ed25519 pubkey size)', () async {
      final derived = await Keyring.publicKeyFor(testMnemonic);
      expect(derived.publicKey.length, equals(32));
    });

    test('address is a valid base58 string of expected length', () async {
      final derived = await Keyring.publicKeyFor(testMnemonic);
      // Solana base58 addresses are 32-44 chars.
      expect(derived.address.length, inInclusiveRange(32, 44));
      expect(
        RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(derived.address),
        isTrue,
      );
    });

    test('invalid mnemonic throws KeyDerivationException', () async {
      expect(
        () => Keyring.publicKeyFor('not a real mnemonic phrase'),
        throwsA(isA<KeyDerivationException>()),
      );
      expect(
        () => Keyring.keyPairFromMnemonic(''),
        throwsA(isA<KeyDerivationException>()),
      );
    });

    test('keyPairFromMnemonic produces a keypair whose address matches publicKeyFor',
        () async {
      final derived = await Keyring.publicKeyFor(testMnemonic);
      final keypair = await Keyring.keyPairFromMnemonic(testMnemonic);
      expect(keypair.address, equals(derived.address));
    });
  });
}
