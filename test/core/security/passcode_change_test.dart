import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';
import 'package:solfare/core/security/passcode_change.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';
  const other = 'legal winner thank year wave sausage worth useful legal '
      'winner thank yellow';

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> backing;

  WalletAccount account(String id, String stored) => WalletAccount(
        id: id,
        address: '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB',
        mnemonic: stored,
        name: 'Wallet $id',
        cardBackground: 'card_1.png',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

  List<WalletAccount> stored() => [
        for (final e in jsonDecode(backing['wallets_v1']!) as List)
          WalletAccount.fromJson(e as Map<String, dynamic>)
      ];

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

  /// An install with a passcode, unlocked, holding sealed mnemonics.
  Future<void> seed(String passcode, List<String> phrases) async {
    final made = await PasscodeCrypto.create(passcode);
    backing[AppLock.passcodeKey] = made.stored;
    WalletKey.hold(made.keys.wrapKey);
    backing['wallets_v1'] = jsonEncode([
      for (var i = 0; i < phrases.length; i++)
        account('$i', MnemonicEnvelope.wrap(phrases[i], made.keys.wrapKey))
            .toJson()
    ]);
  }

  test('the mnemonic opens with the new passcode afterwards', () async {
    await seed('111111', [mnemonic]);

    final result =
        await PasscodeChange.apply(current: '111111', next: '222222');
    expect(result, isA<PasscodeChanged>());

    // What a later cold start does: derive from the digest on disk.
    final keys = await PasscodeCrypto.verifyAndDerive(
        '222222', backing[AppLock.passcodeKey]!);
    expect(keys, isNotNull);
    expect(
      MnemonicEnvelope.unwrap(stored().single.mnemonic, keys!.wrapKey),
      mnemonic,
    );
  });

  test('the old passcode no longer opens anything', () async {
    await seed('111111', [mnemonic]);
    await PasscodeChange.apply(current: '111111', next: '222222');

    expect(
      await PasscodeCrypto.verifyAndDerive(
          '111111', backing[AppLock.passcodeKey]!),
      isNull,
    );
  });

  test('every wallet is resealed, not only the first', () async {
    await seed('111111', [mnemonic, other]);
    await PasscodeChange.apply(current: '111111', next: '222222');

    final keys = await PasscodeCrypto.verifyAndDerive(
        '222222', backing[AppLock.passcodeKey]!);
    final opened = [
      for (final w in stored()) MnemonicEnvelope.unwrap(w.mnemonic, keys!.wrapKey)
    ];
    expect(opened, [mnemonic, other]);
  });

  test('a wrong current passcode changes nothing and counts down', () async {
    await seed('111111', [mnemonic]);
    final before = backing[AppLock.passcodeKey];

    final result =
        await PasscodeChange.apply(current: '999999', next: '222222');

    expect(result, isA<PasscodeChangeWrong>());
    expect((result as PasscodeChangeWrong).remaining, greaterThan(0));
    expect(backing[AppLock.passcodeKey], before);
    expect(MnemonicEnvelope.unwrap(stored().single.mnemonic, WalletKey.value),
        mnemonic);
  });

  test('the key held afterwards is the new one', () async {
    await seed('111111', [mnemonic]);
    await PasscodeChange.apply(current: '111111', next: '222222');

    // Nothing should have to be re-entered to keep using the app.
    expect(
      MnemonicEnvelope.unwrap(stored().single.mnemonic, WalletKey.value),
      mnemonic,
    );
  });

  test('a store that cannot be opened is left untouched', () async {
    await seed('111111', [mnemonic]);
    // A mnemonic sealed with some other key: unwrap will throw.
    final foreign = await PasscodeCrypto.create('999999');
    backing['wallets_v1'] = jsonEncode(
        [account('0', MnemonicEnvelope.wrap(mnemonic, foreign.keys.wrapKey)).toJson()]);
    final before = backing[AppLock.passcodeKey];

    final result =
        await PasscodeChange.apply(current: '111111', next: '222222');

    expect(result, isA<PasscodeChangeFailed>());
    expect(backing[AppLock.passcodeKey], before,
        reason: 'a partial rewrite is how a wallet is lost');
  });
}
