import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/token/mint_info.dart';

void main() {
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
