import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/token/mint_info.dart';

void main() {
  /// Shape taken verbatim from PYUSD on mainnet, a Token-2022 mint in
  /// production use. Real data rather than an invented fixture, because the
  /// two false positives this catches only show up in real data.
  Map<String, dynamic> account({
    List<Map<String, dynamic>> extensions = const [],
    String owner = MintInfo.token2022ProgramId,
    int decimals = 6,
  }) =>
      {
        'owner': owner,
        'data': {
          'parsed': {
            'type': 'mint',
            'info': {'decimals': decimals, 'extensions': extensions},
          },
        },
      };

  group('parsing real Token-2022 mints', () {
    test('a transfer hook with no program set is not a hook', () {
      // PYUSD carries the extension with programId null: nothing runs on
      // transfer, so warning about it would warn about nothing.
      final mint = MintInfo.parse('PYUSD', account(extensions: [
        {
          'extension': 'transferHook',
          'state': {'authority': '2apB', 'programId': null},
        },
      ]));

      expect(mint.hasTransferHook, isFalse);
      expect(mint.hasNotableExtensions, isFalse);
    });

    test('a transfer hook with a program set is a hook', () {
      final mint = MintInfo.parse('M', account(extensions: [
        {
          'extension': 'transferHook',
          'state': {'authority': '2apB', 'programId': 'HookProgram1111'},
        },
      ]));

      expect(mint.hasTransferHook, isTrue);
    });

    test('a zero-rate fee config is not a fee', () {
      // Also PYUSD: the config exists, the rate is zero. Saying "the
      // recipient receives less" would be false.
      final mint = MintInfo.parse('PYUSD', account(extensions: [
        {
          'extension': 'transferFeeConfig',
          'state': {
            'newerTransferFee': {'epoch': 605, 'maximumFee': 0, 'transferFeeBasisPoints': 0},
            'olderTransferFee': {'epoch': 605, 'maximumFee': 0, 'transferFeeBasisPoints': 0},
          },
        },
      ]));

      expect(mint.transferFee, isNull);
      expect(mint.hasNotableExtensions, isFalse);
    });

    test('a real fee is read', () {
      final mint = MintInfo.parse('M', account(extensions: [
        {
          'extension': 'transferFeeConfig',
          'state': {
            'newerTransferFee': {'epoch': 600, 'maximumFee': 5000, 'transferFeeBasisPoints': 250},
            'olderTransferFee': {'epoch': 600, 'maximumFee': 5000, 'transferFeeBasisPoints': 250},
          },
        },
      ]));

      expect(mint.transferFee!.basisPoints, 250);
      expect(mint.transferFee!.maximumFee, 5000);
    });

    test('a pending fee change uses the schedule in force', () {
      final ext = [
        {
          'extension': 'transferFeeConfig',
          'state': {
            'newerTransferFee': {'epoch': 700, 'maximumFee': 9999, 'transferFeeBasisPoints': 900},
            'olderTransferFee': {'epoch': 600, 'maximumFee': 100, 'transferFeeBasisPoints': 100},
          },
        },
      ];

      // Before the new schedule activates, the old rate is what is charged.
      expect(MintInfo.parse('M', account(extensions: ext), currentEpoch: 650).transferFee!.basisPoints, 100);
      // On and after, the new one.
      expect(MintInfo.parse('M', account(extensions: ext), currentEpoch: 700).transferFee!.basisPoints, 900);
    });

    test('only a pending change needs the epoch looked up', () {
      final same = account(extensions: [
        {
          'extension': 'transferFeeConfig',
          'state': {
            'newerTransferFee': {'epoch': 605, 'maximumFee': 0, 'transferFeeBasisPoints': 0},
            'olderTransferFee': {'epoch': 605, 'maximumFee': 0, 'transferFeeBasisPoints': 0},
          },
        },
      ]);
      final pending = account(extensions: [
        {
          'extension': 'transferFeeConfig',
          'state': {
            'newerTransferFee': {'epoch': 700, 'maximumFee': 0, 'transferFeeBasisPoints': 900},
            'olderTransferFee': {'epoch': 600, 'maximumFee': 0, 'transferFeeBasisPoints': 100},
          },
        },
      ]);

      expect(MintInfo.needsEpoch(same), isFalse, reason: 'no change pending, no round trip');
      expect(MintInfo.needsEpoch(pending), isTrue);
      expect(MintInfo.needsEpoch(account()), isFalse);
    });

    test('a permanent delegate is read from its address', () {
      final mint = MintInfo.parse('PYUSD', account(extensions: [
        {
          'extension': 'permanentDelegate',
          'state': {'delegate': '2apBGMsS6ti9RyF5TwQTDswXBWskiJP2LD4cUEDqYJjk'},
        },
      ]));

      expect(mint.hasPermanentDelegate, isTrue);
      expect(mint.hasNotableExtensions, isTrue);
    });

    test('non-transferable is read', () {
      final mint = MintInfo.parse('M', account(extensions: [
        {'extension': 'nonTransferable', 'state': {}},
      ]));
      expect(mint.nonTransferable, isTrue);
    });

    test('a plain SPL mint has no extensions at all', () {
      final mint = MintInfo.parse('USDC', account(owner: MintInfo.tokenProgramId));
      expect(mint.isToken2022, isFalse);
      expect(mint.hasNotableExtensions, isFalse);
    });

    test('metadata extensions change nothing about a transfer', () {
      // PYUSD also carries metadataPointer, tokenMetadata, mintCloseAuthority
      // and confidential transfer config. None of them affect a send.
      final mint = MintInfo.parse('PYUSD', account(extensions: [
        {'extension': 'metadataPointer', 'state': {'metadataAddress': 'X'}},
        {'extension': 'tokenMetadata', 'state': {'name': 'PayPal USD'}},
        {'extension': 'mintCloseAuthority', 'state': {'closeAuthority': '2apB'}},
        {'extension': 'confidentialTransferMint', 'state': {'authority': '2apB'}},
      ]));

      expect(mint.hasNotableExtensions, isFalse);
    });
  });

  group('TransferFee', () {
    test('charges the basis-point rate', () {
      // 1% of 1,000,000 base units.
      const fee = TransferFee(basisPoints: 100, maximumFee: 1000000000);
      expect(fee.feeOn(1000000), 10000);
      expect(fee.netOf(1000000), 990000);
    });

    test('rounds the fee up, the way the program does', () {
      // 0.01% of 15 base units is 0.0015, which the program charges as 1.
      const fee = TransferFee(basisPoints: 1, maximumFee: 1000000000);
      expect(fee.feeOn(15), 1);
    });

    test('never charges more than the cap', () {
      const fee = TransferFee(basisPoints: 500, maximumFee: 5000);
      // 5% of 10,000,000 would be 500,000, but the cap holds.
      expect(fee.feeOn(10000000), 5000);
      expect(fee.netOf(10000000), 9995000);
    });

    test('a zero rate takes nothing', () {
      const fee = TransferFee(basisPoints: 0, maximumFee: 1000);
      expect(fee.feeOn(999999), 0);
      expect(fee.netOf(999999), 999999);
    });

    test('reports the rate as a percentage for display', () {
      expect(const TransferFee(basisPoints: 250, maximumFee: 0).percent, 2.5);
    });
  });

  group('MintInfo', () {
    test('a plain SPL mint has nothing worth warning about', () {
      const mint = MintInfo(
        mint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        programId: MintInfo.tokenProgramId,
        decimals: 6,
      );
      expect(mint.isToken2022, isFalse);
      expect(mint.hasNotableExtensions, isFalse);
    });

    test('any behaviour-changing extension is notable', () {
      const base = MintInfo(mint: 'M', programId: MintInfo.token2022ProgramId, decimals: 9);
      expect(base.hasNotableExtensions, isFalse);

      expect(
        const MintInfo(
          mint: 'M', programId: MintInfo.token2022ProgramId, decimals: 9,
          nonTransferable: true,
        ).hasNotableExtensions,
        isTrue,
      );
      expect(
        const MintInfo(
          mint: 'M', programId: MintInfo.token2022ProgramId, decimals: 9,
          transferFee: TransferFee(basisPoints: 10, maximumFee: 100),
        ).hasNotableExtensions,
        isTrue,
      );
      expect(
        const MintInfo(
          mint: 'M', programId: MintInfo.token2022ProgramId, decimals: 9,
          hasPermanentDelegate: true,
        ).hasNotableExtensions,
        isTrue,
      );
    });
  });
}
