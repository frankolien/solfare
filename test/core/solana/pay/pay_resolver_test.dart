import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/pay/pay_request.dart';
import 'package:solfare/core/solana/pay/pay_resolver.dart';
import 'package:solfare/core/solana/token/token_service.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

void main() {
  // parse() is static — it touches no state. Building native-SOL instructions
  // needs no RPC either, so the datasource here is never actually called.
  final resolver = PayResolver(TokenService(SolanaRpcDataSourceImpl()));

  const merchant = 'CRVideKGnbHTPWLWTJz8mrKGVn7oCVaFHPFhpqJT6Ah';
  const payer = '8xTf7ZLvBqCzHZWmnGL7CxHRWZqL3qYzTNy1MEwSc2Ke';
  const usdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  group('parsing', () {
    test('a bare address is not a pay request', () {
      expect(PayResolver.parse(merchant), isNull);
    });

    test('an unrelated URL is not a pay request', () {
      expect(PayResolver.parse('https://example.com/pay'), isNull);
    });

    test('reads a full transfer request', () {
      final request = PayResolver.parse(
        'solana:$merchant'
        '?amount=25.5'
        '&spl-token=$usdc'
        '&reference=$payer'
        '&label=Blue%20Bottle'
        '&message=Order%20%231847'
        '&memo=table-4',
      );

      expect(request, isA<PayTransferRequest>());
      final transfer = request! as PayTransferRequest;
      expect(transfer.recipient, merchant);
      expect(transfer.amount, 25.5);
      expect(transfer.splToken, usdc);
      expect(transfer.references, [payer]);
      expect(transfer.label, 'Blue Bottle');
      expect(transfer.message, 'Order #1847');
      expect(transfer.memo, 'table-4');
      expect(transfer.isNativeSol, isFalse);
    });

    test('a request with no spl-token pays native SOL', () {
      final transfer = PayResolver.parse('solana:$merchant?amount=1') as PayTransferRequest;
      expect(transfer.isNativeSol, isTrue);
      expect(transfer.amountIsFixed, isTrue);
    });

    test('an open request leaves the amount to the payer', () {
      final transfer = PayResolver.parse('solana:$merchant') as PayTransferRequest;
      expect(transfer.amount, isNull);
      expect(transfer.amountIsFixed, isFalse);
    });

    test('reads a transaction request and exposes its origin', () {
      final request = PayResolver.parse(
        'solana:https%3A%2F%2Fmerchant.example%2Fpay%2F1847?label=Blue%20Bottle',
      );

      expect(request, isA<PayTransactionRequest>());
      final tx = request! as PayTransactionRequest;
      expect(tx.link.toString(), 'https://merchant.example/pay/1847');
      expect(tx.origin, 'merchant.example');
      expect(tx.label, 'Blue Bottle');
    });

    test('a transaction request over plain http is rejected', () {
      expect(PayResolver.parse('solana:http%3A%2F%2Fmerchant.example%2Fpay'), isNull);
    });
  });

  group('building a transfer', () {
    test('a native transfer carries the amount in lamports', () async {
      final request = PayResolver.parse('solana:$merchant?amount=0.25') as PayTransferRequest;
      final instructions = await resolver.buildTransfer(request: request, payer: payer);

      expect(instructions, hasLength(1));
      expect(instructions.single.programId.toBase58(), '11111111111111111111111111111111');
    });

    test('reference keys ride along read-only and non-signer', () async {
      final request = PayResolver.parse('solana:$merchant?amount=1&reference=$payer')
          as PayTransferRequest;
      final instructions = await resolver.buildTransfer(request: request, payer: payer);

      final reference = instructions.single.accounts.last;
      expect(reference.pubKey.toBase58(), payer);
      expect(reference.isSigner, isFalse);
      expect(reference.isWriteable, isFalse);
    });

    test('a memo becomes its own instruction', () async {
      final request =
          PayResolver.parse('solana:$merchant?amount=1&memo=table-4') as PayTransferRequest;
      final instructions = await resolver.buildTransfer(request: request, payer: payer);

      expect(instructions, hasLength(2));
      expect(instructions.last.programId.toBase58(),
          'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');
    });

    test('the payer can supply an amount the request left open', () async {
      final request = PayResolver.parse('solana:$merchant') as PayTransferRequest;
      final instructions =
          await resolver.buildTransfer(request: request, payer: payer, amount: 2);
      expect(instructions, hasLength(1));
    });

    test('an open request with no amount cannot be paid', () async {
      final request = PayResolver.parse('solana:$merchant') as PayTransferRequest;
      expect(
        () => resolver.buildTransfer(request: request, payer: payer),
        throwsA(isA<PayRequestException>()),
      );
    });

    test('a zero amount is refused', () async {
      final request = PayResolver.parse('solana:$merchant?amount=0') as PayTransferRequest;
      expect(
        () => resolver.buildTransfer(request: request, payer: payer),
        throwsA(isA<PayRequestException>()),
      );
    });
  });
}
