import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:solana/dto.dart' show LatestBlockhash;
// Prefixed on purpose: dto.dart exports a same-named Instruction for *parsed*
// transactions, and an unprefixed import gets auto-resolved to it.
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/priority_fee_oracle.dart';
import 'package:solfare/core/solana/tx_outcome.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// What a transaction will cost, resolved before the user commits to it.
class TxEstimate {
  final int computeUnitLimit;
  final int computeUnitsUsed;
  final int priorityFeeLamports;

  // Fixed by the runtime at 5000 per signature, not biddable.
  final int baseFeeLamports;

  const TxEstimate({
    required this.computeUnitLimit,
    required this.computeUnitsUsed,
    required this.priorityFeeLamports,
    required this.baseFeeLamports,
  });

  int get totalFeeLamports => baseFeeLamports + priorityFeeLamports;
  double get totalFeeSol => totalFeeLamports / 1000000000;
}

/// Builds, prices, sends and confirms transactions. A signature from
/// `sendTransaction` only means one node accepted the bytes — the tx can
/// still be dropped, and once its blockhash ages out (150 blocks, ~60s) it
/// can never land, silently and without a fee.
///
/// Every send runs the same four steps:
///   - Simulate to measure compute units and fail before signing.
///   - Budget: request the measured limit and bid a priority fee off what
///     recent blocks charged for these accounts.
///   - Broadcast with node-side retries off; the loop below owns them.
///   - Confirm: poll status, rebroadcasting the same signed bytes (same
///     signature, so a duplicate can't double-spend) until expiry.
class TransactionService {
  final SolanaRpcDataSource _rpc;
  final PriorityFeeOracle _oracle;

  TransactionService(this._rpc) : _oracle = PriorityFeeOracle(_rpc);

  // Runtime ceiling for a single transaction.
  static const int _maxComputeUnits = 1400000;

  // Account state can shift between the dry run and inclusion. 15% covers
  // that without inflating the fee, which is charged on the limit.
  static const double _computeHeadroom = 1.15;

  // Used when an RPC declines to report unitsConsumed. Above a system
  // transfer (~450 CU), below anything that overpays badly.
  static const int _fallbackComputeUnits = 200000;

  static const Duration _statusPollInterval = Duration(milliseconds: 1200);
  static const Duration _rebroadcastInterval = Duration(seconds: 2);

  /// Price [instructions] without sending, so a confirm screen can show a
  /// real fee instead of a guess.
  Future<TxEstimate> estimate({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    FeeLevel feeLevel = FeeLevel.normal,
  }) async {
    final blockhash = await _fetchBlockhash();
    final measured = await _measureComputeUnits(instructions, signers, blockhash);
    final limit = _limitFor(measured);
    final microLamports = await _oracle.microLamportsPerCu(
      writableAccounts: _writableAccounts(instructions, signers.first.publicKey),
      computeUnitLimit: limit,
      level: feeLevel,
    );

    return TxEstimate(
      computeUnitLimit: limit,
      computeUnitsUsed: measured,
      priorityFeeLamports: PriorityFeeOracle.lamportsFor(microLamports, limit),
      baseFeeLamports: 5000 * signers.length,
    );
  }

  /// Send [instructions] and wait for confirmation. On-chain failures come
  /// back as a [TxOutcome] instead of throwing — the UI has to show them
  /// differently from a success. [TxSimulationException] means it never left
  /// the device.
  ///
  /// Expired transactions are rebuilt (new blockhash, higher fee tier) up to
  /// [maxAttempts] times. Safe because expiry is absolute: past
  /// lastValidBlockHeight the original can never be included.
  Future<TxOutcome> sendAndConfirm({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    FeeLevel feeLevel = FeeLevel.normal,
    void Function(TxPhase phase)? onPhase,
    int maxAttempts = 2,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (signers.isEmpty) {
      throw const TxSimulationException('No signer available for this transaction.');
    }

    TxOutcome? lastExpired;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // Escalate the bid on a retry: the first attempt expiring is evidence
      // the market moved above our bid while it sat in the queue.
      final level = attempt == 1 ? feeLevel : _escalate(feeLevel);

      final outcome = await _attempt(
        instructions: instructions,
        signers: signers,
        feeLevel: level,
        onPhase: onPhase,
        timeout: timeout,
      );

      if (outcome.status != TxStatus.expired) return outcome;

      lastExpired = outcome;
      debugLog('[Tx] Attempt $attempt expired before inclusion; rebuilding');
    }

    return lastExpired!;
  }

  /// Sign a transaction somebody else built, broadcast it, and confirm it.
  ///
  /// The payload arrives serialised with an empty slot for our signature, so
  /// the message is signed and the signature written into the first slot
  /// rather than the transaction being rebuilt — rebuilding would change the
  /// bytes the merchant or dapp expects to see land.
  Future<TxOutcome> signAndSendPayload({
    required String base64Tx,
    required solana.Ed25519HDKeyPair signer,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final raw = base64Decode(base64Tx);

    // Layout: [compact-u16 signature count][count * 64 bytes][message].
    var offset = 0;
    var signatureCount = raw[offset++];
    if (signatureCount >= 0x80) {
      signatureCount = (signatureCount & 0x7f) | (raw[offset++] << 7);
    }
    if (signatureCount == 0) {
      throw const TxSimulationException('That transaction has no room for a signature.');
    }

    final messageStart = offset + signatureCount * 64;
    if (messageStart > raw.length) {
      throw const TxSimulationException('That transaction is malformed.');
    }

    final signature = await signer.sign(raw.sublist(messageStart));
    final signed = Uint8List.fromList(raw);
    signed.setRange(offset, offset + 64, signature.bytes);

    final encoded = base64Encode(signed);
    final decoded = encoder.SignedTx.decode(encoded);

    await _rpc.sendTransaction(encoded, skipPreflight: false);
    debugLog('[Tx] Broadcast external payload ${decoded.id}');

    return confirmSigned(
      signature: decoded.id,
      blockhash: decoded.blockhash,
      encoded: encoded,
      timeout: timeout,
    );
  }

  /// Confirm a transaction built elsewhere (a Jupiter route, a dApp payload).
  /// Those carry no block height, so expiry falls back to polling [blockhash]
  /// for validity. Pass [encoded] to keep rebroadcasting, omit it to only
  /// watch when someone else owns delivery.
  Future<TxOutcome> confirmSigned({
    required String signature,
    required String blockhash,
    String? encoded,
    Duration timeout = const Duration(seconds: 90),
  }) =>
      _confirm(
        signature: signature,
        encoded: encoded,
        blockhash: blockhash,
        lastValidBlockHeight: null,
        timeout: timeout,
        computeUnitsUsed: 0,
        computeUnitLimit: 0,
        priorityFeeLamports: 0,
      );

  Future<TxOutcome> _attempt({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    required FeeLevel feeLevel,
    required Duration timeout,
    void Function(TxPhase phase)? onPhase,
  }) async {
    onPhase?.call(TxPhase.preparing);
    final blockhash = await _fetchBlockhash();

    onPhase?.call(TxPhase.simulating);
    final measured = await _measureComputeUnits(instructions, signers, blockhash);
    final limit = _limitFor(measured);

    final microLamports = await _oracle.microLamportsPerCu(
      writableAccounts: _writableAccounts(instructions, signers.first.publicKey),
      computeUnitLimit: limit,
      level: feeLevel,
    );
    final priorityFee = PriorityFeeOracle.lamportsFor(microLamports, limit);

    final signed = await solana.signTransaction(
      blockhash,
      solana.Message(
        instructions: _withBudget(instructions, limit: limit, microLamports: microLamports),
      ),
      signers,
    );
    final encoded = signed.encode();
    final signature = signed.id;

    onPhase?.call(TxPhase.broadcasting);
    // First broadcast keeps preflight on: it is one more chance to catch a
    // bad transaction against a bank fresher than our simulation.
    await _rpc.sendTransaction(encoded, skipPreflight: false);
    debugLog('[Tx] Broadcast $signature (cu=$measured/$limit, priority=$priorityFee lamports)');

    onPhase?.call(TxPhase.confirming);
    return _confirm(
      signature: signature,
      encoded: encoded,
      lastValidBlockHeight: blockhash.lastValidBlockHeight,
      timeout: timeout,
      computeUnitsUsed: measured,
      computeUnitLimit: limit,
      priorityFeeLamports: priorityFee,
    );
  }

  /// Poll for confirmation while rebroadcasting, until the cluster decides
  /// or the blockhash expires.
  Future<TxOutcome> _confirm({
    required String signature,
    required String? encoded,
    required Duration timeout,
    // Exact expiry for transactions we built; blockhash polling for the rest.
    int? lastValidBlockHeight,
    String? blockhash,
    required int computeUnitsUsed,
    required int computeUnitLimit,
    required int priorityFeeLamports,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var broadcasts = 1;
    var lastBroadcast = DateTime.now();
    var lastHeightCheck = DateTime.now();

    TxOutcome result(TxStatus status, {String? error}) => TxOutcome(
          signature: signature,
          status: status,
          error: error,
          computeUnitsUsed: computeUnitsUsed,
          computeUnitLimit: computeUnitLimit,
          priorityFeeLamports: priorityFeeLamports,
          broadcasts: broadcasts,
        );

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_statusPollInterval);

      final status = await _safeStatus(signature);
      if (status != null) {
        if (status['err'] != null) {
          return result(
            TxStatus.failed,
            error: _humanizeError(status['err'], const []),
          );
        }
        final level = status['confirmationStatus'] as String?;
        if (level == 'confirmed' || level == 'finalized') {
          debugLog('[Tx] $signature $level after $broadcasts broadcast(s)');
          return result(TxStatus.confirmed);
        }
      }

      final now = DateTime.now();

      // Keep pushing the same bytes at the cluster. A leader that dropped it
      // once may have room on the next slot, and the identical signature
      // means a duplicate is a no-op rather than a second transfer.
      if (encoded != null && now.difference(lastBroadcast) >= _rebroadcastInterval) {
        lastBroadcast = now;
        broadcasts++;
        try {
          await _rpc.sendTransaction(encoded, skipPreflight: true);
        } catch (e) {
          // Expected once it lands ("already processed"); the status poll is
          // the source of truth, so a failed rebroadcast is never fatal.
          debugLog('[Tx] Rebroadcast $broadcasts ignored: $e');
        }
      }

      if (now.difference(lastHeightCheck) >= const Duration(seconds: 4)) {
        lastHeightCheck = now;
        if (await _hasExpired(lastValidBlockHeight, blockhash)) {
          // One last look: expiry and inclusion can race inside a poll gap.
          final finalStatus = await _safeStatus(signature);
          if (finalStatus != null && finalStatus['err'] == null) {
            return result(TxStatus.confirmed);
          }
          debugLog('[Tx] $signature expired before inclusion');
          return result(TxStatus.expired, error: 'Transaction expired before it was included.');
        }
      }
    }

    return result(TxStatus.expired, error: 'Timed out waiting for confirmation.');
  }

  /// Dry-run the instruction set and read back what it actually costs.
  Future<int> _measureComputeUnits(
    List<encoder.Instruction> instructions,
    List<solana.Ed25519HDKeyPair> signers,
    LatestBlockhash blockhash,
  ) async {
    // Probe with the maximum limit so a genuinely expensive transaction is
    // measured rather than truncated by our own guess.
    final probe = await solana.signTransaction(
      blockhash,
      solana.Message(
        instructions: _withBudget(instructions, limit: _maxComputeUnits, microLamports: 0),
      ),
      signers,
    );

    final Map<String, dynamic> sim;
    try {
      sim = await _rpc.simulateTransaction(probe.encode());
    } catch (e) {
      // A simulation that cannot run is not a transaction that cannot land —
      // fall back to a safe limit rather than blocking the user.
      debugLog('[Tx] Simulation unavailable, using fallback budget: $e');
      return _fallbackComputeUnits;
    }

    final logs = ((sim['logs'] as List?) ?? const []).cast<String>();
    if (sim['err'] != null) {
      throw TxSimulationException(_humanizeError(sim['err'], logs), logs: logs);
    }

    final units = sim['unitsConsumed'];
    if (units is! int || units <= 0) return _fallbackComputeUnits;
    return units;
  }

  /// Compute budget instructions go first — the runtime reads the budget
  /// before executing anything that spends it.
  List<encoder.Instruction> _withBudget(
    List<encoder.Instruction> instructions, {
    required int limit,
    required int microLamports,
  }) =>
      [
        solana.ComputeBudgetInstruction.setComputeUnitLimit(units: limit),
        if (microLamports > 0)
          solana.ComputeBudgetInstruction.setComputeUnitPrice(microLamports: microLamports),
        ...instructions,
      ];

  int _limitFor(int measured) {
    // +300 covers the two compute budget instructions themselves, which the
    // probe measured but which shift slightly in the final transaction.
    final withHeadroom = (measured * _computeHeadroom).ceil() + 300;
    return math.min(math.max(withHeadroom, 1000), _maxComputeUnits);
  }

  Future<LatestBlockhash> _fetchBlockhash() async {
    final data = await _rpc.getLatestBlockhash();
    return LatestBlockhash(
      blockhash: data['blockhash'] as String,
      lastValidBlockHeight: data['lastValidBlockHeight'] as int,
    );
  }

  /// Every account the tx writes to, plus the fee payer — the set the fee
  /// market prices against.
  List<String> _writableAccounts(
    List<encoder.Instruction> instructions,
    solana.Ed25519HDPublicKey feePayer,
  ) {
    final accounts = <String>{feePayer.toBase58()};
    for (final instruction in instructions) {
      for (final account in instruction.accounts) {
        if (account.isWriteable) accounts.add(account.pubKey.toBase58());
      }
    }
    return accounts.toList();
  }

  FeeLevel _escalate(FeeLevel level) => switch (level) {
        FeeLevel.economy => FeeLevel.normal,
        FeeLevel.normal => FeeLevel.turbo,
        FeeLevel.turbo => FeeLevel.turbo,
      };

  Future<Map<String, dynamic>?> _safeStatus(String signature) async {
    try {
      return await _rpc.getSignatureStatus(signature);
    } catch (e) {
      // A flaky status read must not be mistaken for a dropped transaction.
      debugLog('[Tx] Status poll failed: $e');
      return null;
    }
  }

  /// True once the transaction can no longer be included. Uses the block
  /// height when we built the tx, and blockhash validity when we didn't.
  /// A failed read returns false — a flaky RPC is not proof of expiry.
  Future<bool> _hasExpired(int? lastValidBlockHeight, String? blockhash) async {
    try {
      if (lastValidBlockHeight != null) {
        return await _rpc.getBlockHeight() > lastValidBlockHeight;
      }
      if (blockhash != null) return !await _rpc.isBlockhashValid(blockhash);
    } catch (e) {
      debugLog('[Tx] Expiry check failed: $e');
    }
    return false;
  }

  /// Turn a runtime error into something a user can act on. Raw shapes are
  /// `{"InstructionError":[1,{"Custom":6001}]}` or a bare "BlockhashNotFound".
  String _humanizeError(dynamic err, List<String> logs) {
    final joined = logs.join('\n');

    if (joined.contains('insufficient lamports') ||
        joined.contains('Insufficient Funds') ||
        joined.contains('InsufficientFundsForRent')) {
      return 'Not enough SOL to cover the amount plus network fees.';
    }
    if (joined.contains('AccountNotFound') || joined.contains('could not find account')) {
      return 'The destination account does not exist on this network.';
    }

    if (err is String) {
      return switch (err) {
        'BlockhashNotFound' => 'The network was busy and the transaction expired. Try again.',
        'AlreadyProcessed' => 'This transaction was already submitted.',
        'InsufficientFundsForFee' => 'Not enough SOL to pay the network fee.',
        _ => 'Transaction rejected by the network ($err).',
      };
    }

    if (err is Map) {
      final instructionError = err['InstructionError'];
      if (instructionError is List && instructionError.length == 2) {
        final index = instructionError[0];
        final detail = instructionError[1];
        if (detail is String) {
          if (detail == 'InsufficientFunds') {
            return 'Not enough SOL to cover the amount plus network fees.';
          }
          return 'encoder.Instruction $index failed: $detail.';
        }
        if (detail is Map && detail['Custom'] != null) {
          // Program-specific codes mean nothing out of context; the program's
          // own log line is the only readable explanation available.
          final logLine = logs.reversed.firstWhere(
            (l) => l.contains('Error:') || l.contains('failed:'),
            orElse: () => '',
          );
          return logLine.isNotEmpty
              ? 'Program rejected the transaction: ${logLine.split('Error:').last.trim()}'
              : 'Program rejected the transaction (code ${detail['Custom']}).';
        }
      }
    }

    return 'Transaction failed. Please try again.';
  }
}
