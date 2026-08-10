import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';

void main() {
  group('key exchange', () {
    test('a sealed payload opens with the matching keys', () {
      // Both sides generate a keypair, exactly as the handshake does.
      final wallet = SessionCrypto.generateKeyPair();
      final dapp = SessionCrypto.generateKeyPair();

      final sealed = SessionCrypto.seal(
        payload: {'public_key': 'abc', 'session': 'token-1'},
        sessionPrivateKey: wallet.privateKey,
        dappPublicKey: dapp.publicKey,
      );

      // The dapp opens it with its own private key and our public key —
      // ECDH gives both sides the same shared secret.
      final opened = SessionCrypto.open(
        nonce: sealed.nonce,
        payload: sealed.payload,
        sessionPrivateKey: dapp.privateKey,
        dappPublicKey: wallet.publicKey,
      );

      expect(opened['public_key'], 'abc');
      expect(opened['session'], 'token-1');
    });

    test('a third party cannot open it', () {
      final wallet = SessionCrypto.generateKeyPair();
      final dapp = SessionCrypto.generateKeyPair();
      final attacker = SessionCrypto.generateKeyPair();

      final sealed = SessionCrypto.seal(
        payload: {'secret': 'value'},
        sessionPrivateKey: wallet.privateKey,
        dappPublicKey: dapp.publicKey,
      );

      expect(
        () => SessionCrypto.open(
          nonce: sealed.nonce,
          payload: sealed.payload,
          sessionPrivateKey: attacker.privateKey,
          dappPublicKey: wallet.publicKey,
        ),
        throwsA(isA<SessionCryptoException>()),
      );
    });

    test('tampered ciphertext is rejected rather than decrypted', () {
      final wallet = SessionCrypto.generateKeyPair();
      final dapp = SessionCrypto.generateKeyPair();

      final sealed = SessionCrypto.seal(
        payload: {'amount': 1},
        sessionPrivateKey: wallet.privateKey,
        dappPublicKey: dapp.publicKey,
      );

      // Poly1305 authenticates the ciphertext; flipping any of it must fail.
      final tampered = sealed.payload.replaceRange(4, 5, sealed.payload[4] == 'A' ? 'B' : 'A');

      expect(
        () => SessionCrypto.open(
          nonce: sealed.nonce,
          payload: tampered,
          sessionPrivateKey: dapp.privateKey,
          dappPublicKey: wallet.publicKey,
        ),
        throwsA(isA<SessionCryptoException>()),
      );
    });

    test('the wrong nonce fails', () {
      final wallet = SessionCrypto.generateKeyPair();
      final dapp = SessionCrypto.generateKeyPair();

      final first = SessionCrypto.seal(
        payload: {'a': 1},
        sessionPrivateKey: wallet.privateKey,
        dappPublicKey: dapp.publicKey,
      );
      final second = SessionCrypto.seal(
        payload: {'a': 1},
        sessionPrivateKey: wallet.privateKey,
        dappPublicKey: dapp.publicKey,
      );

      expect(
        () => SessionCrypto.open(
          nonce: second.nonce,
          payload: first.payload,
          sessionPrivateKey: dapp.privateKey,
          dappPublicKey: wallet.publicKey,
        ),
        throwsA(isA<SessionCryptoException>()),
      );
    });

    test('each sealing uses a fresh nonce', () {
      final wallet = SessionCrypto.generateKeyPair();
      final dapp = SessionCrypto.generateKeyPair();

      final nonces = {
        for (var i = 0; i < 20; i++)
          SessionCrypto.seal(
            payload: const {'same': 'payload'},
            sessionPrivateKey: wallet.privateKey,
            dappPublicKey: dapp.publicKey,
          ).nonce,
      };

      // A repeated nonce under the same key leaks the plaintext relationship.
      expect(nonces.length, 20);
    });

    test('every connection gets a different keypair', () {
      final keys = {for (var i = 0; i < 20; i++) SessionCrypto.generateKeyPair().publicKey};
      expect(keys.length, 20);
    });

    test('garbage input throws rather than crashing the handler', () {
      final wallet = SessionCrypto.generateKeyPair();
      expect(
        () => SessionCrypto.open(
          nonce: 'not-base58-!!',
          payload: 'also-not-base58-!!',
          sessionPrivateKey: wallet.privateKey,
          dappPublicKey: wallet.publicKey,
        ),
        throwsA(isA<SessionCryptoException>()),
      );
    });
  });

  group('session lifetime', () {
    DappSession session(DateTime lastUsed, {DateTime? created}) => DappSession(
          origin: 'app.example',
          dappPublicKey: 'dapp-key',
          sessionPrivateKey: 'private-key',
          walletAddress: 'wallet',
          sessionToken: 'token',
          createdAt: created ?? lastUsed,
          lastUsedAt: lastUsed,
        );

    test('a recently used session is live', () {
      final now = DateTime(2026, 6, 1);
      expect(session(now.subtract(const Duration(days: 2))).isExpiredAt(now), isFalse);
    });

    test('an idle session expires', () {
      final now = DateTime(2026, 6, 1);
      expect(session(now.subtract(const Duration(days: 31))).isExpiredAt(now), isTrue);
    });

    test('a session used constantly still expires eventually', () {
      // Without an absolute cap, a dapp that pings monthly holds its grant
      // forever, which is not what "I connected to this once" means.
      final now = DateTime(2026, 6, 1);
      final ancient = session(
        now.subtract(const Duration(days: 1)),
        created: now.subtract(DappSession.maxLifetime + const Duration(days: 1)),
      );
      expect(ancient.isExpiredAt(now), isTrue);
    });

    test('a session just inside its lifetime is still live', () {
      final now = DateTime(2026, 6, 1);
      final old = session(
        now.subtract(const Duration(days: 1)),
        created: now.subtract(DappSession.maxLifetime - const Duration(days: 1)),
      );
      expect(old.isExpiredAt(now), isFalse);
    });

    test('use extends the session without changing when it was created', () {
      final now = DateTime(2026, 6, 1);
      final original = session(DateTime(2026, 5, 2), created: DateTime(2026, 5, 1));
      final touched = original.touched(now);

      expect(touched.lastUsedAt, now);
      expect(touched.createdAt, original.createdAt);
      expect(touched.isExpiredAt(now), isFalse);
    });

    test('survives a round trip through storage', () {
      final original = session(DateTime(2026, 5, 5));
      final restored = DappSession.fromJson(original.toJson());

      expect(restored.origin, original.origin);
      expect(restored.dappPublicKey, original.dappPublicKey);
      expect(restored.sessionPrivateKey, original.sessionPrivateKey);
      expect(restored.walletAddress, original.walletAddress);
      // The same instant, not the same wall-clock reading: sessions are
      // stored in UTC now.
      expect(restored.lastUsedAt.isAtSameMomentAs(original.lastUsedAt), isTrue);
    });

    test('a stored session reads back as the same instant in any timezone', () {
      // toIso8601String() on a local DateTime emits no offset and parses
      // back as local, so a session written in UTC+2 and read in UTC-7 used
      // to shift nine hours — nine hours of extra life, or nine hours short.
      final original = session(DateTime(2026, 5, 5, 14, 30));
      final json = original.toJson();
      expect(json['lastUsedAt'], endsWith('Z'),
          reason: 'the stored form has to carry its offset');
      expect(
        DappSession.fromJson(json).lastUsedAt.isAtSameMomentAs(original.lastUsedAt),
        isTrue,
      );
    });
  });

  group('replay', () {
    final session = DappSession(
      origin: 'app.example',
      dappPublicKey: 'dapp-key',
      sessionPrivateKey: 'private-key',
      walletAddress: 'wallet',
      sessionToken: 'token',
      createdAt: DateTime.utc(2026, 5, 1),
      lastUsedAt: DateTime.utc(2026, 5, 1),
    );

    test('a fresh nonce has not been seen', () {
      expect(session.hasSeen('nonce-a'), isFalse);
    });

    test('an accepted nonce is remembered', () {
      // A sealed payload opens every time it is presented, so without this a
      // captured deeplink can be resent verbatim and signed again.
      final after = session.accepting('nonce-a', DateTime.utc(2026, 5, 2));
      expect(after.hasSeen('nonce-a'), isTrue);
      expect(after.lastUsedAt, DateTime.utc(2026, 5, 2));
    });

    test('the window is bounded, oldest dropped first', () {
      var current = session;
      for (var i = 0; i <= DappSession.nonceMemory; i++) {
        current = current.accepting('nonce-$i', DateTime.utc(2026, 5, 2));
      }
      expect(current.seenNonces.length, DappSession.nonceMemory);
      expect(current.hasSeen('nonce-0'), isFalse, reason: 'oldest falls out');
      expect(current.hasSeen('nonce-${DappSession.nonceMemory}'), isTrue);
    });

    test('accepting a nonce does not disturb the rest of the session', () {
      final after = session.accepting('nonce-a', DateTime.utc(2026, 5, 2));
      expect(after.sessionPrivateKey, session.sessionPrivateKey);
      expect(after.createdAt, session.createdAt);
      expect(after.origin, session.origin);
    });
  });
}
