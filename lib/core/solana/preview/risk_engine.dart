import 'package:solfare/core/solana/preview/instruction_decoder.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';

/// Turns a decoded transaction into the warnings worth interrupting someone
/// for.
///
/// Rules read decoded instructions *and* simulated deltas together, never one
/// alone. Instructions without deltas miss a transfer hidden inside CPI;
/// deltas without instructions cannot tell an approval — which moves nothing
/// today and everything tomorrow — from a transfer.
class RiskEngine {
  const RiskEngine();

  /// Native balance that has to stay behind to keep an account rent-exempt.
  /// Spending past it does not fail, it closes the account.
  static const int rentExemptMinimum = 890880;

  /// A priority fee this far above the going rate is worth mentioning, since
  /// it is the one number a malicious payload can inflate without touching
  /// any balance.
  static const int highPriorityFeeLamports = 10000000; // 0.01 SOL

  List<RiskFlag> evaluate({
    required List<DecodedInstruction> instructions,
    required List<BalanceDelta> deltas,
    bool willFail = false,
    bool instructionsUnavailable = false,
    Set<String> previouslyUsedPrograms = const {},
    bool userInitiated = true,
  }) {
    final flags = <RiskFlag>[
      ..._instructionFlags(instructions, previouslyUsedPrograms),
      ..._deltaFlags(deltas, userInitiated: userInitiated),
    ];

    if (instructionsUnavailable) {
      flags.add(const RiskFlag(
        severity: RiskSeverity.caution,
        title: 'Instructions could not be read',
        detail: 'The balance changes below are still from the network\'s own '
            'simulation, but the individual steps could not be decoded.',
      ));
    }

    if (willFail) {
      flags.add(const RiskFlag(
        severity: RiskSeverity.caution,
        title: 'This transaction would fail',
        detail: 'Approving it would still cost the network fee.',
      ));
    }

    flags.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return flags;
  }

  List<RiskFlag> _instructionFlags(
    List<DecodedInstruction> instructions,
    Set<String> previouslyUsed,
  ) {
    final flags = <RiskFlag>[];
    final unknownPrograms = <String>{};

    for (final ix in instructions) {
      switch (ix.kind) {
        case 'approve':
        case 'approveChecked':
          final unlimited = ix.fields['amount'] == InstructionDecoder.unlimitedAmount;
          flags.add(RiskFlag(
            severity: unlimited ? RiskSeverity.danger : RiskSeverity.caution,
            title: unlimited ? 'Unlimited spending approval' : 'Spending approval',
            detail: unlimited
                ? 'Another account is being given permission to move this token '
                    'out of your wallet, with no limit and no expiry.'
                : 'Another account is being given permission to move this token '
                    'out of your wallet.',
            instructionIndex: ix.index,
          ));

        case 'setAuthority':
        case 'authorizeStake':
          flags.add(RiskFlag(
            severity: RiskSeverity.danger,
            title: 'Ownership is changing hands',
            detail: 'This hands control of an account to a different address. '
                'You may not be able to undo it.',
            instructionIndex: ix.index,
          ));

        case 'closeAccount':
          flags.add(RiskFlag(
            severity: RiskSeverity.caution,
            title: 'An account is being closed',
            detail: 'Its rent is reclaimed and sent to '
                '${_short(ix.fields['destination'])}.',
            instructionIndex: ix.index,
          ));

        case 'assign':
          flags.add(RiskFlag(
            severity: RiskSeverity.danger,
            title: 'An account is being handed to another program',
            detail: 'After this, that program controls the account.',
            instructionIndex: ix.index,
          ));

        case 'freezeAccount':
          flags.add(RiskFlag(
            severity: RiskSeverity.caution,
            title: 'A token account is being frozen',
            detail: 'Frozen accounts cannot send or receive until unfrozen.',
            instructionIndex: ix.index,
          ));

        case 'setComputeUnitPrice':
          final micro = int.tryParse(ix.fields['microLamports'] ?? '') ?? 0;
          // 1.4M CU is the ceiling, so this is the worst case for the bid.
          if (micro * 1400000 ~/ 1000000 > highPriorityFeeLamports) {
            flags.add(RiskFlag(
              severity: RiskSeverity.info,
              title: 'High priority fee',
              detail: 'This transaction bids well above the normal rate for '
                  'block space.',
              instructionIndex: ix.index,
            ));
          }
      }

      if (!ix.isKnownProgram && !ix.isNoise) {
        unknownPrograms.add(ix.programId);
      }
    }

    for (final program in unknownPrograms) {
      final seenBefore = previouslyUsed.contains(program);
      flags.add(RiskFlag(
        severity: RiskSeverity.caution,
        title: seenBefore ? 'Unrecognised program' : 'First time using this program',
        detail: seenBefore
            ? 'Solfare does not recognise ${_short(program)}. That does not '
                'make it unsafe, only unverified.'
            : 'You have never approved anything for ${_short(program)} before, '
                'and Solfare does not recognise it.',
      ));
    }

    return flags;
  }

  List<RiskFlag> _deltaFlags(List<BalanceDelta> deltas, {required bool userInitiated}) {
    final flags = <RiskFlag>[];

    for (final d in deltas.where((d) => d.isOwnAccount && d.isNative && !d.isIncoming)) {
      final left = d.postRaw;
      if (left == null || left >= rentExemptMinimum) continue;
      // Below the rent-exempt floor the runtime purges the account, so this
      // is not "sends most of your SOL" — it empties the wallet.
      flags.add(const RiskFlag(
        severity: RiskSeverity.danger,
        title: 'This empties your SOL',
        detail: 'It leaves too little behind to keep the account open, and you '
            'need SOL to sign anything afterwards.',
      ));
    }

    final outgoingMints = deltas
        .where((d) => d.isOwnAccount && !d.isIncoming && !d.isNative)
        .map((d) => d.label)
        .toSet();
    final incoming = deltas.where((d) => d.isOwnAccount && d.isIncoming).isNotEmpty;

    // Tokens leaving with nothing coming back is the shape of a drain — but
    // only when somebody else composed the transaction. On a send the user
    // typed themselves it describes exactly what they asked for, and a
    // warning on every send is how warnings get ignored.
    if (!userInitiated && outgoingMints.isNotEmpty && !incoming) {
      flags.add(RiskFlag(
        severity: RiskSeverity.caution,
        title: 'Nothing comes back',
        detail: outgoingMints.length == 1
            ? '${outgoingMints.first} leaves your wallet and nothing is received in return.'
            : '${outgoingMints.length} tokens leave your wallet and nothing is '
                'received in return.',
      ));
    }

    return flags;
  }

  String _short(String? address) {
    if (address == null || address.isEmpty) return 'another account';
    if (address.length <= 12) return address;
    return '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
  }
}
