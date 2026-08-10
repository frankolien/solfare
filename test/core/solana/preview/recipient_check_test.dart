import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/preview/recipient_check.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Returns whatever account JSON the test hands it. Only getAccountInfo is
/// reached, so the rest throws rather than quietly returning something.
class _FakeRpc implements SolanaRpcDataSource {
  final Map<String, dynamic>? account;
  final Exception? error;

  _FakeRpc({this.account, this.error});

  @override
  Future<Map<String, dynamic>?> getAccountInfo(String address) async {
    if (error != null) throw error!;
    return account;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by this test');
}

void main() {
  Map<String, dynamic> account({
    required String owner,
    String? parsedType,
    bool executable = false,
  }) =>
      {
        'owner': owner,
        'executable': executable,
        'lamports': 2039280,
        if (parsedType != null)
          'data': {
            'parsed': {'type': parsedType, 'info': <String, dynamic>{}},
          },
      };

  const systemProgram = '11111111111111111111111111111111';
  const token2022 = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';
  const tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';

  group('ordinary wallets', () {
    test('an address that has never been used raises nothing', () async {
      // The common case for a fresh wallet: no account exists yet.
      expect(await RecipientCheck(_FakeRpc()).inspect('anyone'), isNull);
    });

    test('a normal system-owned wallet raises nothing', () async {
      final rpc = _FakeRpc(account: account(owner: systemProgram));
      expect(await RecipientCheck(rpc).inspect('anyone'), isNull);
    });
  });

  group('addresses that eat funds', () {
    test('a token mint is danger', () async {
      // The case that lost 0.2 SOL on devnet: a Token-2022 mint accepts the
      // transfer and nothing can withdraw it again.
      final rpc = _FakeRpc(account: account(owner: token2022, parsedType: 'mint'));

      final flag = await RecipientCheck(rpc).inspect('ErCsVMWc');
      expect(flag, isNotNull);
      expect(flag!.severity, RiskSeverity.danger);
      expect(flag.title, contains('token mint'));
      expect(flag.detail, contains('cannot be withdrawn'));
    });

    test('a plain SPL mint is danger too', () async {
      final rpc = _FakeRpc(account: account(owner: tokenProgram, parsedType: 'mint'));
      final flag = await RecipientCheck(rpc).inspect('mint');
      expect(flag!.severity, RiskSeverity.danger);
    });

    test('a token account is danger', () async {
      final rpc = _FakeRpc(account: account(owner: tokenProgram, parsedType: 'account'));

      final flag = await RecipientCheck(rpc).inspect('ata');
      expect(flag!.severity, RiskSeverity.danger);
      expect(flag.title, contains('token account'));
    });

    test('an executable program is danger', () async {
      final rpc = _FakeRpc(
        account: account(owner: 'BPFLoaderUpgradeab1e11111111111111111111111', executable: true),
      );

      final flag = await RecipientCheck(rpc).inspect('program');
      expect(flag!.severity, RiskSeverity.danger);
      expect(flag.title, contains('program'));
    });
  });

  group('everything else', () {
    test('an account owned by some other program is a caution', () async {
      final rpc = _FakeRpc(account: account(owner: 'Stake11111111111111111111111111111111111111'));

      final flag = await RecipientCheck(rpc).inspect('stake');
      expect(flag!.severity, RiskSeverity.caution);
    });

    test('a failed lookup invents no warning', () async {
      // A network error says nothing about the address. Warning on it would
      // be as wrong as missing a real one.
      final rpc = _FakeRpc(error: Exception('rpc down'));
      expect(await RecipientCheck(rpc).inspect('anyone'), isNull);
    });
  });
}
