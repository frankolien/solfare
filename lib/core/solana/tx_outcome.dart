/// Where a transaction is in its lifecycle, so the send sheet can say
/// "confirming" instead of claiming success the moment the RPC replies.
enum TxPhase {
  preparing,
  simulating,

  /// Signature exists but nothing is settled.
  broadcasting,

  /// Polling status and rebroadcasting until the blockhash expires.
  confirming,
}

enum TxStatus {
  confirmed,

  /// Landed on chain and the runtime rejected it. Fees were burned.
  failed,

  /// Blockhash expired before inclusion. Nothing happened on chain and no
  /// fee was charged, so retrying is safe.
  expired,
}

/// Terminal result of a transaction. A signature alone says nothing about
/// whether the transfer happened, hence the status.
class TxOutcome {
  final String signature;
  final TxStatus status;

  /// Null when [status] is confirmed.
  final String? error;

  /// What the simulation measured, before headroom.
  final int computeUnitsUsed;

  final int computeUnitLimit;

  /// On top of the 5000-lamport base signature fee.
  final int priorityFeeLamports;

  /// >1 means early attempts were dropped and the retry loop earned its keep.
  final int broadcasts;

  const TxOutcome({
    required this.signature,
    required this.status,
    this.error,
    this.computeUnitsUsed = 0,
    this.computeUnitLimit = 0,
    this.priorityFeeLamports = 0,
    this.broadcasts = 1,
  });

  bool get isConfirmed => status == TxStatus.confirmed;

  /// Base signature fee plus the priority bid. Expired transactions cost
  /// nothing.
  int get totalFeeLamports =>
      status == TxStatus.expired ? 0 : 5000 + priorityFeeLamports;

  @override
  String toString() =>
      'TxOutcome($status, sig=$signature, cu=$computeUnitsUsed/$computeUnitLimit, '
      'priority=${priorityFeeLamports}lamports, broadcasts=$broadcasts, err=$error)';
}

/// Rejected before it ever reached the cluster — failed simulation, missing
/// funds, unsigned account. Carries the logs so the UI can show more than
/// "transaction failed".
class TxSimulationException implements Exception {
  final String message;
  final List<String> logs;

  const TxSimulationException(this.message, {this.logs = const []});

  @override
  String toString() => message;
}
