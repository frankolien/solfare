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
    DappSession session(DateTime lastUsed) => DappSession(
          origin: 'app.example',
          dappPublicKey: 'dapp-key',
          sessionPrivateKey: 'private-key',
          walletAddress: 'wallet',
          sessionToken: 'token',
          createdAt: DateTime(2026, 1, 1),
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

    test('use extends the session without changing when it was created', () {
      final now = DateTime(2026, 6, 1);
      final original = session(DateTime(2026, 1, 2));
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
      expect(restored.lastUsedAt, original.lastUsedAt);
    });
  });
}
