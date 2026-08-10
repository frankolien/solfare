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

  /// Proven dead: the blockhash is past its last valid block height and the
  /// cluster has no record of the signature. Nothing happened on chain and no
  /// fee was charged, so retrying is safe.
  expired,

  /// Broadcast, and we never found out what became of it — the poll ran out
  /// of time, or the status read itself kept failing.
  ///
  /// Deliberately not [expired]. Everything downstream tells the user an
  /// expired transaction cost nothing and invites them to try again, and a
  /// transaction that is merely unresolved may still be sitting in the queue.
  /// Saying "nothing happened" about one of those is how a user sends twice.
  unknown,
}

/// What the cluster charges per signature. A protocol fact rather than a
/// service detail, so it lives beside the outcome that has to price it.
const int lamportsPerSignature = 5000;

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
    this.signatureCount = 1,
  });

  /// How many signatures the transaction carried, so the base fee can be
  /// stated rather than assumed to be one. A stake delegation signs twice.
  final int signatureCount;

  bool get isConfirmed => status == TxStatus.confirmed;

  /// Whether it is safe to tell the user nothing happened. Only true when the
  /// cluster confirmed the blockhash is dead and has no record of the
  /// signature — never for [TxStatus.unknown].
  bool get provenNotToHaveLanded => status == TxStatus.expired;

  /// Base signature fee plus the priority bid. Expired transactions cost
  /// nothing; unknown ones may well have cost the fee, so they are charged
  /// for here rather than quietly reported as free.
  int get totalFeeLamports => status == TxStatus.expired
      ? 0
      : lamportsPerSignature * signatureCount + priorityFeeLamports;

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
