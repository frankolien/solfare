import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:solfare/core/solana/lamports.dart';
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
  double get totalFeeSol => Lamports.toSol(totalFeeLamports);
}

/// Builds, prices, sends and confirms transactions.
class TransactionService {
  final SolanaRpcDataSource _rpc;
  final PriorityFeeOracle _oracle;

  TransactionService(this._rpc, {PriorityFeeOracle? oracle})
      : _oracle = oracle ?? PriorityFeeOracle(_rpc);

  // Runtime ceiling for a single transaction.
  static const int _maxComputeUnits = 1400000;

  // Charged per signature by the runtime, and not biddable.
  static const int lamportsPerSignature = 5000;

  // Account state can shift between the dry run and inclusion.
  static const double _computeHeadroom = 1.15;

  // Used when an RPC declines to report unitsConsumed.
  static const int _fallbackComputeUnits = 200000;

  static const Duration _statusPollInterval = Duration(milliseconds: 1200);
  static const Duration _rebroadcastInterval = Duration(seconds: 2);

  /// Price [instructions] without sending, so a confirm screen can show a real
  /// fee instead of a guess.
  Future<TxEstimate> estimate({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    FeeLevel feeLevel = FeeLevel.normal,
  }) async {
    if (signers.isEmpty) {
      throw const TxSimulationException('No signer available for this transaction.');
    }
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
      baseFeeLamports: lamportsPerSignature * signers.length,
    );
  }

  /// Send [instructions] and wait for confirmation.
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
    // A caller asking for no attempts still has to get an outcome rather than a
    // null-check crash on the way out.
    final attempts = math.max(1, maxAttempts);

    // One deadline for the whole call, not one per attempt.
    final deadline = DateTime.now().add(timeout);
    TxOutcome? lastExpired;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      // Escalate the bid on a retry: the first attempt expiring is evidence the
      // market moved above our bid while it sat in the queue.
      final level = attempt == 1 ? feeLevel : _escalate(feeLevel);

      final outcome = await _attempt(
        instructions: instructions,
        signers: signers,
        feeLevel: level,
        onPhase: onPhase,
        deadline: deadline,
      );

      // Only a proven expiry is safe to rebuild on.
      if (outcome.status != TxStatus.expired) return outcome;

      lastExpired = outcome;
      debugLog('[Tx] Attempt $attempt expired before inclusion; rebuilding');

      // A retry needs room to finish, not merely a deadline that has not yet
      // passed.
      if (deadline.difference(DateTime.now()) < _minimumAttemptBudget) break;
    }

    return lastExpired ??
        const TxOutcome(
          signature: '',
          status: TxStatus.unknown,
          error: 'Timed out waiting for confirmation.',
        );
  }

  // Below this there is no point starting another attempt: simulate, price,
  // sign and broadcast alone eat most of it, leaving nothing to confirm with.
  static const Duration _minimumAttemptBudget = Duration(seconds: 20);

  /// Sign a transaction somebody else built, without broadcasting it.
  Future<String> signPayloadOnly({
    required String base64Tx,
    required solana.Ed25519HDKeyPair signer,
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

    final slot = _signatureSlotFor(base64Tx, signer, signatureCount);
    final signature = await signer.sign(raw.sublist(messageStart));
    final signed = Uint8List.fromList(raw);
    signed.setRange(offset + slot * 64, offset + slot * 64 + 64, signature.bytes);
    return base64Encode(signed);
  }

  int _signatureSlotFor(
    String base64Tx,
    solana.Ed25519HDKeyPair signer,
    int signatureCount,
  ) {
    final encoder.SignedTx tx;
    try {
      tx = encoder.SignedTx.decode(base64Tx);
    } catch (e) {
      // Undecodable means the slot cannot be established.
      debugLog('[Tx] Could not read the payload to place a signature: $e');
      throw const TxSimulationException('That transaction could not be read.');
    }

    final keys = tx.compiledMessage.accountKeys;
    final ours = signer.publicKey;
    for (var i = 0; i < signatureCount && i < keys.length; i++) {
      if (keys[i] == ours) return i;
    }

    throw const TxSimulationException(
      'That transaction does not ask for a signature from this wallet.',
    );
  }

  /// Sign a transaction somebody else built, broadcast it, and confirm it.
  Future<TxOutcome> signAndSendPayload({
    required String base64Tx,
    required solana.Ed25519HDKeyPair signer,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final encoded = await signPayloadOnly(base64Tx: base64Tx, signer: signer);
    final decoded = encoder.SignedTx.decode(encoded);

    try {
      await _rpc.sendTransaction(encoded, skipPreflight: false);
    } catch (e) {
      debugLog('[Tx] External payload rejected on broadcast: $e');
      throw TxSimulationException(_humanizeSendFailure(e));
    }
    debugLog('[Tx] Broadcast external payload ${decoded.id}');

    return confirmSigned(
      signature: decoded.id,
      blockhash: decoded.blockhash,
      encoded: encoded,
      timeout: timeout,
    );
  }

  /// Confirm a transaction built elsewhere (a Jupiter route, a dApp payload).
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
        deadline: DateTime.now().add(timeout),
        computeUnitsUsed: 0,
        computeUnitLimit: 0,
        priorityFeeLamports: 0,
      );

  Future<TxOutcome> _attempt({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    required FeeLevel feeLevel,
    required DateTime deadline,
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
    // First broadcast keeps preflight on: it is one more chance to catch a bad
    // transaction against a bank fresher than our simulation.
    try {
      await _rpc.sendTransaction(encoded, skipPreflight: false);
    } catch (e) {
      debugLog('[Tx] First broadcast rejected: $e');
      throw TxSimulationException(_humanizeSendFailure(e));
    }
    debugLog('[Tx] Broadcast $signature (cu=$measured/$limit, priority=$priorityFee lamports)');

    onPhase?.call(TxPhase.confirming);
    return _confirm(
      signature: signature,
      encoded: encoded,
      lastValidBlockHeight: blockhash.lastValidBlockHeight,
      deadline: deadline,
      computeUnitsUsed: measured,
      computeUnitLimit: limit,
      priorityFeeLamports: priorityFee,
      signatureCount: signers.length,
    );
  }

  // Poll for confirmation while rebroadcasting, until the cluster decides or
  // the blockhash expires.
  Future<TxOutcome> _confirm({
    required String signature,
    required String? encoded,
    required DateTime deadline,
    // Exact expiry for transactions we built; blockhash polling for the rest.
    int? lastValidBlockHeight,
    String? blockhash,
    required int computeUnitsUsed,
    required int computeUnitLimit,
    required int priorityFeeLamports,
    int signatureCount = 1,
  }) async {
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
          signatureCount: signatureCount,
        );

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_statusPollInterval);

      final read = await _safeStatus(signature);
      final status = read.status;
      if (status != null) {
        if (status['err'] != null) {
          // getSignatureStatuses says a transaction failed but never why, and
          // every readable branch of _humanizeError is driven by the logs.
          final logs = await _safeLogs(signature);
          return result(
            TxStatus.failed,
            error: _humanizeError(status['err'], logs),
          );
        }
        final level = status['confirmationStatus'] as String?;
        if (level == 'confirmed' || level == 'finalized') {
          debugLog('[Tx] $signature $level after $broadcasts broadcast(s)');
          return result(TxStatus.confirmed);
        }
      }

      final now = DateTime.now();

      // Keep pushing the same bytes at the cluster.
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
          final finalRead = await _safeStatus(signature);
          final finalStatus = finalRead.status;

          // Same bar as the main loop.
          if (finalStatus != null && finalStatus['err'] == null) {
            final level = finalStatus['confirmationStatus'] as String?;
            if (level == 'confirmed' || level == 'finalized') {
              return result(TxStatus.confirmed);
            }
          }

          // Only the cluster answering "I have no record of this" proves the
          // transaction is dead.
          if (!finalRead.readable) {
            debugLog('[Tx] $signature past expiry but status unreadable; still polling');
            continue;
          }

          debugLog('[Tx] $signature expired before inclusion');
          return result(TxStatus.expired, error: 'Transaction expired before it was included.');
        }
      }
    }

    return result(
      TxStatus.unknown,
      error: 'Still waiting on the network. Check the transaction before sending again.',
    );
  }

  Future<int> _measureComputeUnits(
    List<encoder.Instruction> instructions,
    List<solana.Ed25519HDKeyPair> signers,
    LatestBlockhash blockhash,
  ) async {
    // Probe with the maximum limit so a genuinely expensive transaction is
    // measured rather than truncated by our own guess.
    final probe = encoder.SignedTx(
      compiledMessage: solana.Message(
        instructions: _withBudget(instructions, limit: _maxComputeUnits, microLamports: 0),
      ).compile(
        recentBlockhash: blockhash.blockhash,
        feePayer: signers.first.publicKey,
      ),
      signatures: [
        for (final signer in signers)
          encoder.Signature(List<int>.filled(64, 0), publicKey: signer.publicKey),
      ],
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

  // Compute budget instructions go first — the runtime reads the budget before
  // executing anything that spends it.
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
    final Map<String, dynamic> data;
    try {
      data = await _rpc.getLatestBlockhash();
    } catch (e) {
      debugLog('[Tx] Blockhash fetch failed: $e');
      throw const TxSimulationException('Could not reach the network. Nothing was sent.');
    }

    final blockhash = data['blockhash'];
    final height = data['lastValidBlockHeight'];
    if (blockhash is! String || height is! int) {
      // Casting straight through turns a malformed response into a type error,
      // which reaches the user as a crash rather than as a message.
      throw const TxSimulationException('The network returned something unreadable.');
    }
    return LatestBlockhash(blockhash: blockhash, lastValidBlockHeight: height);
  }

  // Every account the tx writes to, plus the fee payer — the set the fee market
  // prices against.
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

  Future<List<String>> _safeLogs(String signature) async {
    try {
      return await _rpc.getTransactionLogs(signature);
    } catch (e) {
      debugLog('[Tx] Log lookup failed: $e');
      return const [];
    }
  }

  // A broadcast rejection arrives wrapped by the RPC client, so the useful part
  // is inside the message rather than in a typed error.
  String _humanizeSendFailure(Object error) {
    final text = error.toString();
    if (text.contains('BlockhashNotFound')) {
      return 'The network was busy and the transaction expired before it was sent. Try again.';
    }
    if (text.contains('InsufficientFundsForFee') || text.contains('insufficient lamports')) {
      return 'Not enough SOL to pay the network fee.';
    }
    if (text.contains('AlreadyProcessed')) {
      return 'This transaction was already submitted.';
    }
    return 'The network would not accept this transaction. Nothing was sent.';
  }

  // Reads the signature's status, keeping "the RPC could not tell us" apart
  // from "the cluster has no record of it".
  Future<_StatusRead> _safeStatus(String signature) async {
    try {
      return _StatusRead.ok(await _rpc.getSignatureStatus(signature));
    } catch (e) {
      debugLog('[Tx] Status poll failed: $e');
      return const _StatusRead.unreadable();
    }
  }

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
          return 'Step $index of the transaction failed: $detail.';
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

// The outcome of one status poll.
class _StatusRead {
  final bool readable;
  final Map<String, dynamic>? status;

  const _StatusRead.ok(this.status) : readable = true;
  const _StatusRead.unreadable()
      : readable = false,
        status = null;
}
