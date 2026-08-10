/// How much attention a [RiskFlag] deserves.
enum RiskSeverity { info, caution, danger }

/// Something about a transaction the user should see before approving.
class RiskFlag {
  final RiskSeverity severity;
  final String title;
  final String detail;

  /// Instruction this came from, or null when it came from the deltas.
  final int? instructionIndex;

  const RiskFlag({
    required this.severity,
    required this.title,
    required this.detail,
    this.instructionIndex,
  });

  @override
  String toString() => '[${severity.name}] $title';
}

/// One account's balance change, in base units.
class BalanceDelta {
  final String? mint;
  final String owner;

  /// Signed, in the token's smallest unit.
  final int rawDelta;
  final int decimals;
  final String? symbol;

  /// True when [owner] is the wallet being asked to sign.
  final bool isOwnAccount;

  /// Balance the simulation left behind, when known.
  final int? postRaw;

  const BalanceDelta({
    required this.mint,
    required this.owner,
    required this.rawDelta,
    required this.decimals,
    required this.isOwnAccount,
    this.symbol,
    this.postRaw,
  });

  bool get isNative => mint == null;
  bool get isIncoming => rawDelta > 0;

  double get uiDelta {
    var divisor = 1.0;
    for (var i = 0; i < decimals; i++) {
      divisor *= 10;
    }
    return rawDelta / divisor;
  }

  /// Label for the token, falling back to a shortened mint when no symbol is
  /// known — never a guess at what the token might be.
  String get label {
    if (isNative) return 'SOL';
    if (symbol != null && symbol!.isNotEmpty) return symbol!;
    final m = mint!;
    return m.length <= 8 ? m : '${m.substring(0, 4)}…${m.substring(m.length - 4)}';
  }

  @override
  String toString() => '$label ${rawDelta > 0 ? '+' : ''}$uiDelta';
}

/// A single instruction, resolved as far as we can honestly resolve it.
class DecodedInstruction {
  final int index;
  final String programId;

  /// Null when the program is not in the registry.
  final String? programName;

  /// Machine-readable operation, e.g. `transfer`, `approve`, `setAuthority`.
  final String kind;

  /// One line for the sheet, e.g. "Send 0.5 SOL to 8xTf…9Qm".
  final String summary;

  /// Decoded arguments, kept as strings so the UI never re-parses.
  final Map<String, String> fields;

  const DecodedInstruction({
    required this.index,
    required this.programId,
    required this.kind,
    required this.summary,
    this.programName,
    this.fields = const {},
  });

  static const String unknownKind = 'unknown';

  bool get isKnownProgram => programName != null;

  /// Compute budget instructions are ours, not the user's intent.
  bool get isNoise => kind == 'setComputeUnitLimit' || kind == 'setComputeUnitPrice';

  @override
  String toString() => '#$index ${programName ?? programId} $kind';
}

/// Everything the approval sheet needs.
class TxPreview {
  final List<BalanceDelta> deltas;
  final List<RiskFlag> flags;
  final List<DecodedInstruction> instructions;

  /// From the simulation, so it is the fee the transaction will actually pay.
  final int feeLamports;
  final int computeUnits;

  /// True when the simulation itself failed.
  final bool willFail;
  final String? failureReason;

  /// Set when the RPC could not simulate at all.
  final bool unverified;

  /// Set when the transaction cannot be made at all — a non-transferable mint,
  /// a missing account.
  final bool blocked;

  const TxPreview({
    required this.deltas,
    required this.flags,
    required this.instructions,
    required this.feeLamports,
    required this.computeUnits,
    this.willFail = false,
    this.failureReason,
    this.unverified = false,
    this.blocked = false,
  });

  const TxPreview.unverified(String reason)
      : deltas = const [],
        flags = const [],
        instructions = const [],
        feeLamports = 0,
        computeUnits = 0,
        willFail = false,
        failureReason = reason,
        unverified = true,
        blocked = false;

  /// This transaction cannot be made.
  const TxPreview.blocked(String reason)
      : deltas = const [],
        flags = const [],
        instructions = const [],
        feeLamports = 0,
        computeUnits = 0,
        willFail = false,
        failureReason = reason,
        unverified = false,
        blocked = true;

  /// Deltas that leave or enter the signer's own accounts.
  List<BalanceDelta> get ownDeltas =>
      deltas.where((d) => d.isOwnAccount).toList();

  RiskSeverity? get worstSeverity => flags.isEmpty
      ? null
      : flags.map((f) => f.severity).reduce((a, b) => a.index >= b.index ? a : b);

  bool get hasDanger => worstSeverity == RiskSeverity.danger;

  /// Whether the sheet should make the user break stride before approving.
  bool get needsDeliberateApproval =>
      hasDanger || unverified || willFail || blocked;

  /// Instructions worth showing — compute budget is stripped.
  List<DecodedInstruction> get visibleInstructions =>
      instructions.where((i) => !i.isNoise).toList();

  @override
  String toString() =>
      'TxPreview(${deltas.length} deltas, ${flags.length} flags, '
      'fee=$feeLamports, willFail=$willFail, unverified=$unverified)';
}
