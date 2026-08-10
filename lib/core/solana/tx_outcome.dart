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

  /// Landed on chain and the runtime rejected it.
  failed,

  /// Proven dead: the blockhash is past its last valid block height and the
  /// cluster has no record of the signature.
  expired,

  /// Broadcast, and we never found out what became of it — the poll ran out of
  /// time, or the status read itself kept failing.
  unknown,
}

/// What the cluster charges per signature.
const int lamportsPerSignature = 5000;

/// Terminal result of a transaction.
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
    this.signatureCount = 1,
  });

  /// How many signatures the transaction carried, so the base fee can be stated
  /// rather than assumed to be one.
  final int signatureCount;

  bool get isConfirmed => status == TxStatus.confirmed;

  /// Whether it is safe to tell the user nothing happened.
  bool get provenNotToHaveLanded => status == TxStatus.expired;

  /// Base signature fee plus the priority bid.
  int get totalFeeLamports => status == TxStatus.expired
      ? 0
      : lamportsPerSignature * signatureCount + priorityFeeLamports;

  @override
  String toString() =>
      'TxOutcome($status, sig=$signature, cu=$computeUnitsUsed/$computeUnitLimit, '
      'priority=${priorityFeeLamports}lamports, broadcasts=$broadcasts, err=$error)';
}

/// Rejected before it ever reached the cluster — failed simulation, missing
/// funds, unsigned account.
class TxSimulationException implements Exception {
  final String message;
  final List<String> logs;

  const TxSimulationException(this.message, {this.logs = const []});

  @override
  String toString() => message;
}
