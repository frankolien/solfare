/// How much attention a [RiskFlag] deserves. Ordering matters — flags are
/// sorted by this, and the highest one drives the sheet's overall tone.
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

/// One account's balance change, in base units. Native SOL has a null [mint].
class BalanceDelta {
  final String? mint;
  final String owner;

  /// Signed, in the token's smallest unit. Negative leaves the wallet.
  final int rawDelta;
  final int decimals;
  final String? symbol;

  /// True when [owner] is the wallet being asked to sign.
  final bool isOwnAccount;

  const BalanceDelta({
    required this.mint,
    required this.owner,
    required this.rawDelta,
    required this.decimals,
    required this.isOwnAccount,
    this.symbol,
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

  /// Label for the token, falling back to a shortened mint when no symbol
  /// is known — never a guess at what the token might be.
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

  /// Null when the program is not in the registry. Never a guess.
  final String? programName;

  /// Machine-readable operation, e.g. `transfer`, `approve`, `setAuthority`.
  /// [unknownKind] when the program is known but the discriminator is not.
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

  /// Compute budget instructions are ours, not the user's intent. They are
  /// decoded so the risk engine can read the fee, and hidden from the list.
  bool get isNoise => kind == 'setComputeUnitLimit' || kind == 'setComputeUnitPrice';

  @override
  String toString() => '#$index ${programName ?? programId} $kind';
}

/// Everything the approval sheet needs. Built by the preview engine from one
/// simulation; nothing here comes from whoever asked for the signature.
class TxPreview {
  final List<BalanceDelta> deltas;
  final List<RiskFlag> flags;
  final List<DecodedInstruction> instructions;

  /// From the simulation, so it is the fee the transaction will actually pay.
  final int feeLamports;
  final int computeUnits;

  /// True when the simulation itself failed. The deltas and flags are still
  /// worth showing — a preview that says "this will fail, here is why" is
  /// the most useful one there is.
  final bool willFail;
  final String? failureReason;

  /// Set when the RPC could not simulate at all. The sheet must then say it
  /// could not verify the transaction rather than imply it is safe.
  final bool unverified;

  const TxPreview({
    required this.deltas,
    required this.flags,
    required this.instructions,
    required this.feeLamports,
    required this.computeUnits,
    this.willFail = false,
    this.failureReason,
    this.unverified = false,
  });

  const TxPreview.unverified(String reason)
      : deltas = const [],
        flags = const [],
        instructions = const [],
        feeLamports = 0,
        computeUnits = 0,
        willFail = false,
        failureReason = reason,
        unverified = true;

  /// Deltas that leave or enter the signer's own accounts.
  List<BalanceDelta> get ownDeltas =>
      deltas.where((d) => d.isOwnAccount).toList();

  RiskSeverity? get worstSeverity => flags.isEmpty
      ? null
      : flags.map((f) => f.severity).reduce((a, b) => a.index >= b.index ? a : b);

  bool get hasDanger => worstSeverity == RiskSeverity.danger;

  /// Instructions worth showing — compute budget is stripped.
  List<DecodedInstruction> get visibleInstructions =>
      instructions.where((i) => !i.isNoise).toList();

  @override
  String toString() =>
      'TxPreview(${deltas.length} deltas, ${flags.length} flags, '
      'fee=$feeLamports, willFail=$willFail, unverified=$unverified)';
}
