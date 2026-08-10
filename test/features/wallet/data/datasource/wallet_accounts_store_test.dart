import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory fake for FlutterSecureStorage's platform channel.
  late Map<String, String> backing;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    backing = {};
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
        case 'containsKey':
          return backing.containsKey(args['key']);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  WalletAccount makeAccount(String id) => WalletAccount(
        id: id,
        address: '11111111111111111111111111111111',
        mnemonic: 'mnemonic-$id',
        name: 'Wallet $id',
        cardBackground: 'card_1.png',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

  group('WalletAccountsStore', () {
    test('loadAll on a fresh store returns empty', () async {
      final s = WalletAccountsStore();
      expect(await s.loadAll(), isEmpty);
    });

    test('saveAll → loadAll round-trip preserves accounts in order', () async {
      final s = WalletAccountsStore();
      await s.saveAll([makeAccount('a'), makeAccount('b')]);
      final loaded = await s.loadAll();
      expect(loaded.map((w) => w.id).toList(), equals(['a', 'b']));
    });

    test('getActive returns null on an empty store', () async {
      expect(await WalletAccountsStore().getActive(), isNull);
    });

    test('getActive falls back to first wallet when pointer is missing', () async {
      final s = WalletAccountsStore();
      await s.saveAll([makeAccount('a'), makeAccount('b')]);
      final active = await s.getActive();
      expect(active!.id, equals('a'));
      // And the fallback choice should now be persisted.
      expect(await s.getActiveId(), equals('a'));
    });

    test('getActive falls back to first when pointer is dangling', () async {
      final s = WalletAccountsStore();
      await s.saveAll([makeAccount('a')]);
      await s.setActiveId('ghost-id-that-does-not-exist');
      final active = await s.getActive();
      expect(active!.id, equals('a'));
    });

    test('wipe clears the wallet list and the active pointer', () async {
      final s = WalletAccountsStore();
      await s.saveAll([makeAccount('a')]);
      await s.setActiveId('a');
      await s.wipe();
      expect(await s.loadAll(), isEmpty);
      expect(await s.getActiveId(), isNull);
    });

    group('a blob that will not decode', () {
      test('is refused, not reported as an empty store', () async {
        // The whole point. An empty list here is acted on by offering to
        // create a wallet, and creating one overwrites this blob.
        backing['wallets_v1'] = 'not json at all';
        expect(
          WalletAccountsStore().loadAll(),
          throwsA(isA<CorruptWalletStoreException>()),
        );
      });

      test('is refused when the JSON parses but the entries do not', () async {
        backing['wallets_v1'] = '[{"id": 42}]';
        expect(
          WalletAccountsStore().loadAll(),
          throwsA(isA<CorruptWalletStoreException>()),
        );
      });

      test('is refused when the payload is not a list', () async {
        backing['wallets_v1'] = '{"id": "a"}';
        expect(
          WalletAccountsStore().loadAll(),
          throwsA(isA<CorruptWalletStoreException>()),
        );
      });

      test('survives the read — nothing overwrites it', () async {
        const original = 'not json at all';
        backing['wallets_v1'] = original;
        final s = WalletAccountsStore();
        await expectLater(s.loadAll(), throwsA(isA<CorruptWalletStoreException>()));
        await expectLater(s.getActive(), throwsA(isA<CorruptWalletStoreException>()));
        expect(backing['wallets_v1'], original,
            reason: 'an unreadable wallet is still a wallet');
      });

      test('an absent blob is still just an empty store', () async {
        // "Nothing stored" and "stored but unreadable" have to stay apart in
        // both directions, or a fresh install becomes an error screen.
        expect(await WalletAccountsStore().loadAll(), isEmpty);
      });

      test('an empty string is an empty store, not a decode failure', () async {
        backing['wallets_v1'] = '';
        expect(await WalletAccountsStore().loadAll(), isEmpty);
      });
    });

    test('newId produces unique 32-char hex strings', () {
      final ids = List.generate(50, (_) => WalletAccountsStore.newId());
      expect(ids.toSet().length, equals(ids.length));
      for (final id in ids) {
        expect(id.length, equals(32));
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
      }
    });
  });
}
