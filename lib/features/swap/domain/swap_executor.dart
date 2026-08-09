import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/swap/data/datasource/jupiter_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// What a route is worth, before anyone commits to it.
class SwapQuote {
  final int outAmountRaw;
  final double priceImpactPct;

  const SwapQuote({required this.outAmountRaw, this.priceImpactPct = 0});
}

/// A route Jupiter built and we have signed. Nothing has been broadcast: the
/// signature is a local operation, and [send] is the step that leaves the
/// device.
class PreparedSwap {
  final String signedTransaction;
  final String requestId;
  final int outAmountRaw;

  const PreparedSwap({
    required this.signedTransaction,
    required this.requestId,
    required this.outAmountRaw,
  });
}

class SwapResult {
  final String? signature;
  final String? error;

  const SwapResult.landed(String this.signature) : error = null;
  const SwapResult.failed(String this.error) : signature = null;

  bool get isConfirmed => error == null;
}

/// Raised when Jupiter declines to build a route at all.
class SwapUnavailableException implements Exception {
  final String message;

  const SwapUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Orders a Jupiter route, signs it, and hands it back for execution.
///
/// The swap screen and the market's buy sheet are the same three steps with
/// different chrome, and two of the steps are easy to get subtly wrong:
/// patching a signature into a v0 transaction that arrives with an empty
/// slot, and not reporting a swap as failed when Jupiter has merely stopped
/// waiting for it. Both live here once.
class SwapExecutor {
  static const int defaultSlippageBps = 50;

  final JupiterDataSource _jupiter;
  final TransactionService _tx;

  SwapExecutor({JupiterDataSource? jupiter, SolanaRpcDataSource? rpc})
      : _jupiter = jupiter ?? JupiterDataSource(),
        _tx = TransactionService(rpc ?? SolanaRpcDataSourceImpl());

  /// Price only. Without a taker Jupiter returns no transaction, so this
  /// cannot be executed and cannot be mistaken for something that can.
  Future<SwapQuote> quote({
    required String inputMint,
    required String outputMint,
    required int amountRaw,
    int slippageBps = defaultSlippageBps,
  }) async {
    final order = await _jupiter.getQuote(
      inputMint: inputMint,
      outputMint: outputMint,
      amount: amountRaw,
      slippageBps: slippageBps,
    );
    return SwapQuote(
      outAmountRaw: int.parse(order['outAmount'].toString()),
      priceImpactPct: double.tryParse(order['priceImpactPct']?.toString() ?? '') ?? 0,
    );
  }

  /// Re-orders with the wallet attached and signs the result.
  ///
  /// A displayed quote carries no transaction, so the route that gets signed
  /// is always freshly built — which is also why the amount is re-checked
  /// here rather than assumed from the quote.
  Future<PreparedSwap> prepare({
    required String inputMint,
    required String outputMint,
    required int amountRaw,
    required String walletAddress,
    required solana.Ed25519HDKeyPair keyPair,
    int slippageBps = defaultSlippageBps,
  }) async {
    final order = await _jupiter.getQuote(
      inputMint: inputMint,
      outputMint: outputMint,
      amount: amountRaw,
      slippageBps: slippageBps,
      taker: walletAddress,
    );

    final base64Tx = order['transaction'] as String?;
    final requestId = order['requestId'] as String?;
    if (base64Tx == null || base64Tx.isEmpty || requestId == null) {
      throw SwapUnavailableException(
        (order['errorMessage'] ?? order['error'] ?? 'No route for this swap right now.')
            .toString(),
      );
    }

    final signed = await _sign(base64Decode(base64Tx), keyPair);
    return PreparedSwap(
      signedTransaction: base64Encode(signed),
      requestId: requestId,
      outAmountRaw: int.tryParse(order['outAmount']?.toString() ?? '') ?? 0,
    );
  }

  /// Hands the signed route back to Jupiter, which broadcasts and polls on
  /// its own infrastructure.
  Future<SwapResult> send(PreparedSwap prepared) async {
    final result = await _jupiter.execute(
      signedTransaction: prepared.signedTransaction,
      requestId: prepared.requestId,
    );

    final status = result['status']?.toString();
    final signature =
        (result['signature'] ?? result['txid'] ?? result['transactionId'])?.toString();
    debugLog('[Swap] execute -> status=$status sig=$signature code=${result['code']}');

    if (status == 'Success' && signature != null) return SwapResult.landed(signature);

    // Jupiter giving up on its own polling is not the same as the swap
    // failing. If there is a signature, the chain is the authority on it.
    if (signature != null) {
      final outcome = await _tx.confirmSigned(
        signature: signature,
        blockhash: encoder.SignedTx.decode(prepared.signedTransaction).blockhash,
      );
      if (outcome.isConfirmed) return SwapResult.landed(signature);
      return SwapResult.failed(outcome.error ?? 'The swap did not confirm.');
    }

    return SwapResult.failed((result['error'] ?? 'Swap failed').toString());
  }

  // Jupiter returns a v0 VersionedTransaction with a placeholder signature
  // slot. Layout: [compact-u16 sig count][sigs * 64 bytes][message]. We sign
  // the message and patch our signature into the first slot.
  Future<Uint8List> _sign(Uint8List txBytes, solana.Ed25519HDKeyPair keyPair) async {
    var offset = 0;
    var sigCount = txBytes[offset++];
    if (sigCount >= 0x80) {
      sigCount = (sigCount & 0x7f) | (txBytes[offset++] << 7);
    }

    final messageBytes = txBytes.sublist(offset + (sigCount * 64));
    final signature = await keyPair.sign(messageBytes);

    final signed = Uint8List.fromList(txBytes);
    for (var i = 0; i < 64; i++) {
      signed[offset + i] = signature.bytes[i];
    }
    return signed;
  }
}
