import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/passcode_gate.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  late Map<String, String> backing;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  WalletAccount account(String id, String stored) => WalletAccount(
        id: id,
        address: '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB',
        mnemonic: stored,
        name: 'Wallet $id',
        cardBackground: 'card_1.png',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

  void seedWallets(List<WalletAccount> wallets) {
    backing['wallets_v1'] = jsonEncode([for (final w in wallets) w.toJson()]);
  }

  List<WalletAccount> storedWallets() =>
      [for (final e in jsonDecode(backing['wallets_v1']!) as List)
        WalletAccount.fromJson(e as Map<String, dynamic>)];

  setUp(() {
    backing = {};
    WalletKey.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return backing[args['key']];
        case 'write':
          backing[args['key']] = args['value'] as String;
          return null;
        case 'delete':
          backing.remove(args['key']);
          return null;
        case 'readAll':
          return Map<String, String>.from(backing);
        case 'deleteAll':
          backing.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    WalletKey.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('upgrading a v1 install', () {
    test('unlocking wraps the mnemonic and upgrades the digest', () async {
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic)]);

      expect(await PasscodeGate.verify('123456'), isA<PasscodeAccepted>());

      expect(backing[AppLock.passcodeKey]!.startsWith('v2:'), isTrue);
      final stored = storedWallets().single.mnemonic;
      expect(MnemonicEnvelope.isWrapped(stored), isTrue);
      expect(stored.contains('abandon'), isFalse);
    });

    test('and the key held opens what was just wrapped', () async {
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic)]);
      await PasscodeGate.verify('123456');

      expect(
        MnemonicEnvelope.unwrap(storedWallets().single.mnemonic, WalletKey.value),
        mnemonic,
      );
    });

    test('a second unlock still opens it', () async {
      // The migration has to be reproducible across sessions, not just
      // within the one that ran it.
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic)]);
      await PasscodeGate.verify('123456');

      WalletKey.resetForTest();
      await PasscodeGate.verify('123456');
      expect(
        MnemonicEnvelope.unwrap(storedWallets().single.mnemonic, WalletKey.value),
        mnemonic,
      );
    });

    test('every wallet is wrapped, not only the active one', () async {
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic), account('b', mnemonic)]);
      await PasscodeGate.verify('123456');

      for (final w in storedWallets()) {
        expect(MnemonicEnvelope.isWrapped(w.mnemonic), isTrue);
        expect(MnemonicEnvelope.unwrap(w.mnemonic, WalletKey.value), mnemonic);
      }
    });
  });

  group('a migration that was interrupted', () {
    test('a v2 digest over plaintext mnemonics is finished on the next unlock',
        () async {
      // The exact half-state the ordering is designed to produce: the digest
      // was written and the process died before the wrap.
      final made = await PasscodeCrypto.create('123456');
      backing[AppLock.passcodeKey] = made.stored;
      seedWallets([account('a', mnemonic)]);

      await PasscodeGate.verify('123456');

      final stored = storedWallets().single.mnemonic;
      expect(MnemonicEnvelope.isWrapped(stored), isTrue,
          reason: 'the wrap runs on every unlock, not only on upgrade');
      expect(MnemonicEnvelope.unwrap(stored, WalletKey.value), mnemonic);
    });

    test('a mix of wrapped and plaintext is completed without double-wrapping',
        () async {
      final made = await PasscodeCrypto.create('123456');
      backing[AppLock.passcodeKey] = made.stored;
      final already = MnemonicEnvelope.wrap(mnemonic, made.keys.wrapKey);
      seedWallets([account('a', already), account('b', mnemonic)]);

      await PasscodeGate.verify('123456');

      for (final w in storedWallets()) {
        expect(MnemonicEnvelope.unwrap(w.mnemonic, WalletKey.value), mnemonic,
            reason: 'wrapping an already-wrapped entry would nest it');
      }
    });

    test('unlocking an already-migrated store changes nothing', () async {
      final made = await PasscodeCrypto.create('123456');
      backing[AppLock.passcodeKey] = made.stored;
      seedWallets([account('a', MnemonicEnvelope.wrap(mnemonic, made.keys.wrapKey))]);
      final before = backing['wallets_v1'];

      await PasscodeGate.verify('123456');
      expect(backing['wallets_v1'], before);
    });
  });

  group('locking', () {
    test('drops the key, so a stored mnemonic can no longer be opened', () async {
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic)]);
      await PasscodeGate.verify('123456');
      final stored = storedWallets().single.mnemonic;

      AppLock.instance.adopt();
      AppLock.instance.lock();

      expect(WalletKey.isHeld, isFalse);
      expect(
        () => MnemonicEnvelope.unwrap(stored, WalletKey.value),
        throwsA(isA<MnemonicLockedException>()),
      );
      AppLock.instance.resetForTest();
    });
  });

  group('a wrong passcode', () {
    test('wraps nothing and holds no key', () async {
      backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
      seedWallets([account('a', mnemonic)]);

      expect(await PasscodeGate.verify('999999'), isA<PasscodeWrong>());
      expect(WalletKey.isHeld, isFalse);
      expect(storedWallets().single.mnemonic, mnemonic);
    });
  });
}
