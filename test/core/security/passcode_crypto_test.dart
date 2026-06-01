import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/passcode_crypto.dart';

void main() {
  group('PasscodeCrypto', () {
    test('hash → verify round-trip succeeds for the same passcode', () async {
      final stored = await PasscodeCrypto.hash('123456');
      expect(await PasscodeCrypto.verify('123456', stored), isTrue);
    });

    test('verify rejects a wrong passcode', () async {
      final stored = await PasscodeCrypto.hash('123456');
      expect(await PasscodeCrypto.verify('123457', stored), isFalse);
      expect(await PasscodeCrypto.verify('', stored), isFalse);
    });

    test('hash produces a unique salt per call (no collisions)', () async {
      final a = await PasscodeCrypto.hash('123456');
      final b = await PasscodeCrypto.hash('123456');
      expect(a, isNot(equals(b)));
      // Both must still verify against the same input.
      expect(await PasscodeCrypto.verify('123456', a), isTrue);
      expect(await PasscodeCrypto.verify('123456', b), isTrue);
    });

    test('hash output uses the v1 envelope format', () async {
      final stored = await PasscodeCrypto.hash('123456');
      expect(stored.startsWith('v1:'), isTrue);
      expect(stored.split(':').length, equals(4));
      expect(PasscodeCrypto.isLegacyPlaintext(stored), isFalse);
    });

    test('legacy plaintext passcodes still verify (migration path)', () async {
      // Pre-hashing installs stored the passcode as raw text.
      const legacy = '123456';
      expect(PasscodeCrypto.isLegacyPlaintext(legacy), isTrue);
      expect(await PasscodeCrypto.verify('123456', legacy), isTrue);
      expect(await PasscodeCrypto.verify('999999', legacy), isFalse);
    });

    test('verify rejects malformed stored values without throwing', () async {
      expect(await PasscodeCrypto.verify('123456', 'v1:not:enough'), isFalse);
      expect(await PasscodeCrypto.verify('123456', 'v1:!!!:100:!!!'), isFalse);
      expect(await PasscodeCrypto.verify('123456', 'v2:salt:100:hash'), isFalse);
    });
  });
}
