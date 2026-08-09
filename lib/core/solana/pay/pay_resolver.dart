import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solana/solana_pay.dart' as pay;
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/core/solana/pay/pay_request.dart';
import 'package:solfare/core/solana/token/token_service.dart';
import 'package:solfare/core/util/app_log.dart';

/// Turns a scanned `solana:` URL into something payable.
///
/// Parsing leans on package:solana's solana_pay module so the wallet follows
/// the spec rather than a reading of it. Everything after parsing — building
/// instructions, talking to a merchant, checking what comes back — lives here
/// because that is where the trust decisions are.
class PayResolver {
  final TokenService _tokens;
  final http.Client _client;

  PayResolver(this._tokens, {http.Client? client}) : _client = client ?? http.Client();

  /// Classify a scanned string. No network, no signing.
  ///
  /// Returns null when this is not a Solana Pay URL at all, which is the
  /// common case: most QR codes in a wallet are a bare address.
  static PayRequest? parse(String raw) {
    final url = raw.trim();
    if (!url.toLowerCase().startsWith('solana:')) return null;

    // A transaction request points at an https link; a transfer request has a
    // base58 recipient. Trying the transaction shape first keeps a link that
    // happens to parse as an address from being treated as one.
    final transaction = pay.SolanaTransactionRequest.tryParse(url);
    if (transaction != null) {
      return PayTransactionRequest(
        link: transaction.link,
        label: transaction.label,
        message: transaction.message,
      );
    }

    final transfer = pay.SolanaPayRequest.tryParse(url);
    if (transfer == null) return null;

    return PayTransferRequest(
      recipient: transfer.recipient.toBase58(),
      amount: transfer.amount?.toDouble(),
      splToken: transfer.splToken?.toBase58(),
      references: [
        for (final r in transfer.reference ?? const <solana.Ed25519HDPublicKey>[])
          r.toBase58(),
      ],
      label: transfer.label,
      message: transfer.message,
      memo: transfer.memo,
    );
  }

  /// Build the instructions for a transfer request.
  ///
  /// [amount] overrides the request's own figure, for the case where the
  /// merchant left it open and the payer typed one.
  Future<List<encoder.Instruction>> buildTransfer({
    required PayTransferRequest request,
    required String payer,
    double? amount,
  }) async {
    final value = amount ?? request.amount;
    if (value == null || value <= 0) {
      throw const PayRequestException('This request has no amount to pay.');
    }

    final payerKey = solana.Ed25519HDPublicKey.fromBase58(payer);
    final instructions = <encoder.Instruction>[];

    if (request.isNativeSol) {
      instructions.add(solana.SystemInstruction.transfer(
        fundingAccount: payerKey,
        recipientAccount: solana.Ed25519HDPublicKey.fromBase58(request.recipient),
        lamports: (value * 1000000000).round(),
      ));
    } else {
      final mint = await _tokens.mintInfo(request.splToken!);
      var factor = 1.0;
      for (var i = 0; i < mint.decimals; i++) {
        factor *= 10;
      }
      instructions.addAll(await _tokens.buildTransfer(
        mint: mint,
        owner: payer,
        recipient: request.recipient,
        amount: (value * factor).round(),
      ));
    }

    if (request.references.isNotEmpty) {
      instructions[instructions.length - 1] =
          _withReferences(instructions.last, request.references);
    }

    if (request.memo != null && request.memo!.isNotEmpty) {
      instructions.add(solana.MemoInstruction(signers: [payerKey], memo: request.memo!));
    }

    return instructions;
  }

  /// Attach the merchant's reference keys to the transfer.
  ///
  /// Read-only and non-signer, always. They exist so the merchant can find
  /// the transaction by watching those addresses; any other role would let a
  /// reference key authorise something.
  encoder.Instruction _withReferences(encoder.Instruction instruction, List<String> references) {
    return encoder.Instruction(
      programId: instruction.programId,
      accounts: [
        ...instruction.accounts,
        for (final reference in references)
          encoder.AccountMeta.readonly(
            pubKey: solana.Ed25519HDPublicKey.fromBase58(reference),
            isSigner: false,
          ),
      ],
      data: instruction.data,
    );
  }

  /// Ask a transaction-request endpoint who it is, before anything is signed.
  Future<PayMerchant> fetchMerchant(PayTransactionRequest request) async {
    final response = await HttpRetry.send(
      () => _client.get(request.link, headers: {'Accept': 'application/json'}),
    );
    if (response.statusCode != 200) {
      throw PayRequestException('That merchant is not responding (HTTP ${response.statusCode}).');
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final label = body['label'] as String?;
      if (label == null) throw const PayRequestException('That merchant sent an invalid response.');
      return PayMerchant(label: label, iconUri: body['icon'] as String?);
    } on PayRequestException {
      rethrow;
    } catch (e) {
      debugLog('[Pay] merchant GET failed to parse: $e');
      throw const PayRequestException('That merchant sent an invalid response.');
    }
  }

  /// Ask the merchant to build the transaction, then check what comes back.
  ///
  /// Returns the base64 payload only if it is safe to show: the wallet must
  /// be the fee payer, and no signature can be required from a key we do not
  /// control. Everything else about the payload is the preview's job.
  Future<String> fetchTransaction({
    required PayTransactionRequest request,
    required String account,
  }) async {
    final response = await HttpRetry.send(
      () => _client.post(
        request.link,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'account': account}),
      ),
    );
    if (response.statusCode != 200) {
      throw PayRequestException('That merchant could not build the payment (HTTP ${response.statusCode}).');
    }

    final String base64Tx;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      base64Tx = body['transaction'] as String;
    } catch (e) {
      debugLog('[Pay] transaction POST failed to parse: $e');
      throw const PayRequestException('That merchant sent an invalid payment.');
    }

    _assertSafeToSign(base64Tx, account);
    return base64Tx;
  }

  void _assertSafeToSign(String base64Tx, String account) {
    final encoder.SignedTx tx;
    try {
      tx = encoder.SignedTx.decode(base64Tx);
    } catch (e) {
      debugLog('[Pay] merchant transaction could not be decoded: $e');
      throw const PayRequestException('That payment could not be read.');
    }

    final keys = tx.compiledMessage.accountKeys;
    if (keys.isEmpty || keys.first.toBase58() != account) {
      // Signing a transaction we do not pay for means signing something whose
      // costs and effects belong to someone else's account.
      throw const PayRequestException(
          'That payment asks your wallet to sign for a different account.');
    }

    final required = tx.compiledMessage.requiredSignatureCount;
    if (required > 1) {
      throw const PayRequestException(
          'That payment needs signatures from accounts you do not control.');
    }
  }
}
