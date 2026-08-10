/// A scanned Solana Pay request, in the two shapes the spec defines.
sealed class PayRequest {
  const PayRequest();

  /// Merchant-supplied display text.
  String? get label;
  String? get message;
}

/// Everything needed to pay is in the URL: the wallet builds the transaction.
class PayTransferRequest extends PayRequest {
  final String recipient;

  /// Null means the merchant left the amount to the payer.
  final double? amount;

  /// Null pays native SOL.
  final String? splToken;

  /// Opaque keys the merchant watches for to reconcile the payment.
  final List<String> references;

  @override
  final String? label;
  @override
  final String? message;

  /// Written on chain via the memo program, visible to everyone forever.
  final String? memo;

  const PayTransferRequest({
    required this.recipient,
    this.amount,
    this.splToken,
    this.references = const [],
    this.label,
    this.message,
    this.memo,
  });

  bool get isNativeSol => splToken == null;
  bool get amountIsFixed => amount != null;
}

/// The merchant builds the transaction; the wallet fetches, checks and signs
/// it.
class PayTransactionRequest extends PayRequest {
  final Uri link;

  @override
  final String? label;
  @override
  final String? message;

  const PayTransactionRequest({required this.link, this.label, this.message});

  /// The only trustworthy identity in the whole exchange.
  String get origin => link.host;
}

/// What a transaction-request endpoint says about itself, fetched before
/// anything is signed so the user sees who is asking first.
class PayMerchant {
  final String label;
  final String? iconUri;

  const PayMerchant({required this.label, this.iconUri});
}

class PayRequestException implements Exception {
  final String message;
  const PayRequestException(this.message);

  @override
  String toString() => message;
}
