import 'dart:convert';

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

  group('v2 envelope keys', () {
    test('the stored digest is not the wrapping key', () async {
      // The single thing this design turns on. If the stored value were the
      // key, reading the keychain would be equivalent to knowing the
      // passcode and the whole exercise would be theatre.
      final made = await PasscodeCrypto.create('123456');
      expect(made.keys.authKey, isNot(made.keys.wrapKey));

      final storedBytes = base64Decode(made.stored.split(':')[3]);
      expect(storedBytes, orderedEquals(made.keys.authKey));
      expect(storedBytes, isNot(orderedEquals(made.keys.wrapKey)));
    });

    test('the same passcode against the same digest gives the same key', () async {
      // Otherwise nothing wrapped on one unlock could be opened on the next.
      final made = await PasscodeCrypto.create('123456');
      final again = await PasscodeCrypto.verifyAndDerive('123456', made.stored);
      expect(again, isNotNull);
      expect(again!.wrapKey, orderedEquals(made.keys.wrapKey));
    });

    test('a different passcode gives a different key', () async {
      final a = await PasscodeCrypto.create('123456');
      final b = await PasscodeCrypto.create('654321');
      expect(a.keys.wrapKey, isNot(orderedEquals(b.keys.wrapKey)));
    });

    test('a wrong passcode derives nothing at all', () async {
      final made = await PasscodeCrypto.create('123456');
      expect(await PasscodeCrypto.verifyAndDerive('999999', made.stored), isNull);
    });

    test('both keys are 32 bytes', () async {
      final made = await PasscodeCrypto.create('123456');
      expect(made.keys.authKey.length, 32);
      expect(made.keys.wrapKey.length, 32);
    });

    test('a v2 digest is not marked as needing an upgrade', () async {
      final made = await PasscodeCrypto.create('123456');
      expect(PasscodeCrypto.needsUpgrade(made.stored), isFalse);
      expect(PasscodeCrypto.isLegacyPlaintext(made.stored), isFalse);
    });
  });

  group('upgrading an existing install', () {
    test('a v1 digest still verifies, and yields keys to upgrade with', () async {
      // The migration path. The user has a v1 digest and a plaintext
      // mnemonic; verifying gives us the wrapKey to wrap it with.
      final v1 = await PasscodeCrypto.hash('123456');
      expect(PasscodeCrypto.needsUpgrade(v1), isTrue);

      final keys = await PasscodeCrypto.verifyAndDerive('123456', v1);
      expect(keys, isNotNull);
      expect(keys!.wrapKey.length, 32);
      expect(await PasscodeCrypto.verifyAndDerive('999999', v1), isNull);
    });

    test('a v1 digest derives the same key every time', () async {
      // It reuses the v1 salt, so re-deriving on a later unlock opens what
      // the first one wrapped — the migration is idempotent because of this.
      final v1 = await PasscodeCrypto.hash('123456');
      final first = await PasscodeCrypto.verifyAndDerive('123456', v1);
      final second = await PasscodeCrypto.verifyAndDerive('123456', v1);
      expect(first!.wrapKey, orderedEquals(second!.wrapKey));
    });

    test('a plaintext digest verifies and yields keys too', () async {
      expect(PasscodeCrypto.needsUpgrade('123456'), isTrue);
      final keys = await PasscodeCrypto.verifyAndDerive('123456', '123456');
      expect(keys, isNotNull);
      expect(await PasscodeCrypto.verifyAndDerive('999999', '123456'), isNull);
    });
  });
}
