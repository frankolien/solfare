import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/solana/tx_outcome.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Answers only what a given test needs; anything else throws rather than
/// quietly returning a plausible value.
class _FakeRpc implements SolanaRpcDataSource {
  final Map<String, dynamic>? blockhash;
  final Object? blockhashError;
  final Map<String, dynamic>? status;
  final List<String> logs;
  int logLookups = 0;
  int sends = 0;

  _FakeRpc({
    this.blockhash,
    this.blockhashError,
    this.status,
    this.logs = const [],
  });

  @override
  Future<Map<String, dynamic>> getLatestBlockhash({String commitment = 'confirmed'}) async {
    if (blockhashError != null) throw blockhashError!;
    return blockhash!;
  }

  @override
  Future<Map<String, dynamic>?> getSignatureStatus(String signature) async => status;

  @override
  Future<List<String>> getTransactionLogs(String signature) async {
    logLookups++;
    return logs;
  }

  @override
  Future<String> sendTransaction(String tx, {bool skipPreflight = false}) async {
    sends++;
    return 'signature';
  }

  @override
  Future<int> getBlockHeight() async => 1;

  @override
  Future<bool> isBlockhashValid(String blockhash) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by this test');
}

void main() {
  const mnemonic =
      'wagon top around adjust brush lounge acquire toilet fault fatal gadget dawn';

  late solana.Ed25519HDKeyPair wallet;
  late solana.Ed25519HDKeyPair other;

  setUpAll(() async {
    wallet = await solana.Ed25519HDKeyPair.fromMnemonic(mnemonic, account: 0);
    other = await solana.Ed25519HDKeyPair.fromMnemonic(mnemonic, account: 1);
  });

  /// A transaction with empty signature slots, the shape a dapp or a merchant
  /// hands over for signing.
  String unsignedPayload({
    required List<solana.Ed25519HDKeyPair> signers,
    required solana.Ed25519HDPublicKey feePayer,
  }) {
    final message = solana.Message(
      instructions: [
        solana.SystemInstruction.transfer(
          fundingAccount: feePayer,
          recipientAccount: other.publicKey,
          lamports: 1000,
        ),
      ],
    );
    final compiled = message.compile(
      recentBlockhash: '11111111111111111111111111111111',
      feePayer: feePayer,
    );
    return encoder.SignedTx(
      compiledMessage: compiled,
      signatures: [
        for (final signer in signers)
          encoder.Signature(List<int>.filled(64, 0), publicKey: signer.publicKey),
      ],
    ).encode();
  }

  List<int> slotBytes(String base64Tx, int slot) {
    final raw = base64Decode(base64Tx);
    var offset = 1; // single-byte compact-u16 for the counts used here
    return raw.sublist(offset + slot * 64, offset + slot * 64 + 64);
  }

  group('signPayloadOnly', () {
    test('signs the slot that belongs to this wallet', () async {
      final service = TransactionService(_FakeRpc());
      final payload = unsignedPayload(signers: [wallet], feePayer: wallet.publicKey);

      final signed = await service.signPayloadOnly(base64Tx: payload, signer: wallet);
      expect(slotBytes(signed, 0).every((b) => b == 0), isFalse);
    });

    test('a payload this wallet is not asked to sign is refused', () async {
      // Sponsored and relayed payloads put somebody else in slot zero.
      // Writing there anyway builds a transaction that fails on chain with
      // nothing to explain it.
      final service = TransactionService(_FakeRpc());
      final payload = unsignedPayload(signers: [other], feePayer: other.publicKey);

      expect(
        () => service.signPayloadOnly(base64Tx: payload, signer: wallet),
        throwsA(isA<TxSimulationException>()),
      );
    });

    test('signs slot one when somebody else is paying', () async {
      // The case the old code got wrong: it always wrote slot zero, so a
      // sponsored or relayed payload got this wallet's signature dropped into
      // the fee payer's slot and failed on chain with nothing to explain it.
      final service = TransactionService(_FakeRpc());
      final message = solana.Message(
        instructions: [
          solana.SystemInstruction.transfer(
            fundingAccount: other.publicKey,
            recipientAccount: wallet.publicKey,
            lamports: 1000,
          ),
          solana.SystemInstruction.transfer(
            fundingAccount: wallet.publicKey,
            recipientAccount: other.publicKey,
            lamports: 500,
          ),
        ],
      );
      final compiled = message.compile(
        recentBlockhash: '11111111111111111111111111111111',
        feePayer: other.publicKey,
      );
      expect(compiled.accountKeys[0], other.publicKey, reason: 'the payer signs first');
      expect(compiled.accountKeys[1], wallet.publicKey);

      final payload = encoder.SignedTx(
        compiledMessage: compiled,
        signatures: [
          encoder.Signature(List<int>.filled(64, 0), publicKey: other.publicKey),
          encoder.Signature(List<int>.filled(64, 0), publicKey: wallet.publicKey),
        ],
      ).encode();

      final signed = await service.signPayloadOnly(base64Tx: payload, signer: wallet);
      expect(slotBytes(signed, 0).every((b) => b == 0), isTrue,
          reason: 'the fee payer signs for themselves');
      expect(slotBytes(signed, 1).every((b) => b == 0), isFalse);
    });

    test('an unreadable payload is refused rather than signed on a guess', () async {
      final service = TransactionService(_FakeRpc());
      expect(
        () => service.signPayloadOnly(base64Tx: base64Encode([1, 2, 3]), signer: wallet),
        throwsA(isA<TxSimulationException>()),
      );
    });

    test('a payload with no signature slot is refused', () async {
      final service = TransactionService(_FakeRpc());
      expect(
        () => service.signPayloadOnly(base64Tx: base64Encode([0, 9, 9]), signer: wallet),
        throwsA(isA<TxSimulationException>()),
      );
    });
  });

  group('confirming a failure', () {
    test('reads the logs before trying to explain what went wrong', () async {
      // getSignatureStatuses reports that a transaction failed and never why.
      // Without the logs every readable branch is unreachable.
      final rpc = _FakeRpc(
        status: {'err': {'InstructionError': [1, {'Custom': 6001}]}, 'confirmationStatus': null},
        logs: const ['Program log: Error: slippage tolerance exceeded'],
      );
      final service = TransactionService(rpc);

      final outcome = await service.confirmSigned(
        signature: 'sig',
        blockhash: '11111111111111111111111111111111',
        timeout: const Duration(seconds: 3),
      );

      expect(outcome.status, TxStatus.failed);
      expect(rpc.logLookups, 1);
      expect(outcome.error, contains('slippage'));
    });

    test('falls back to the plain message when the logs cannot be read', () async {
      final rpc = _FakeRpc(
        status: {'err': {'InstructionError': [1, {'Custom': 6001}]}},
        logs: const [],
      );
      final outcome = await TransactionService(rpc).confirmSigned(
        signature: 'sig',
        blockhash: '11111111111111111111111111111111',
        timeout: const Duration(seconds: 3),
      );

      expect(outcome.status, TxStatus.failed);
      expect(outcome.error, contains('6001'));
    });

    test('a landed transaction is confirmed without asking for logs', () async {
      final rpc = _FakeRpc(status: {'err': null, 'confirmationStatus': 'confirmed'});
      final outcome = await TransactionService(rpc).confirmSigned(
        signature: 'sig',
        blockhash: '11111111111111111111111111111111',
        timeout: const Duration(seconds: 3),
      );

      expect(outcome.status, TxStatus.confirmed);
      expect(rpc.logLookups, 0);
    });
  });

  group('guards', () {
    test('estimating with no signer says so instead of throwing a range error', () {
      expect(
        () => TransactionService(_FakeRpc()).estimate(instructions: const [], signers: const []),
        throwsA(isA<TxSimulationException>()),
      );
    });

    test('sending with no signer says so', () {
      expect(
        () => TransactionService(_FakeRpc())
            .sendAndConfirm(instructions: const [], signers: const []),
        throwsA(isA<TxSimulationException>()),
      );
    });

    test('a malformed blockhash response is a message, not a type error', () {
      final rpc = _FakeRpc(blockhash: const {'blockhash': 42});
      expect(
        () => TransactionService(rpc).estimate(instructions: const [], signers: [wallet]),
        throwsA(isA<TxSimulationException>()),
      );
    });

    test('an unreachable network is a message, not a raw exception', () {
      final rpc = _FakeRpc(blockhashError: Exception('connection closed'));
      expect(
        () => TransactionService(rpc).estimate(instructions: const [], signers: [wallet]),
        throwsA(isA<TxSimulationException>()),
      );
    });
  });
}
