import 'dart:typed_data';

import 'package:solana/dto.dart' show LatestBlockhash;
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/solana/preview/instruction_decoder.dart';
import 'package:solfare/core/solana/preview/risk_engine.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/util/json.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Works out what a transaction will do, before it is signed.
///
/// The balance changes come from the cluster's own simulation rather than
/// from whoever asked for the signature, which is the entire point: a dapp
/// can describe its transaction however it likes, and the simulation still
/// reports what the transaction actually moves.
class PreviewEngine {
  final SolanaRpcDataSource _rpc;
  final InstructionDecoder _decoder;
  final RiskEngine _risk;

  PreviewEngine(this._rpc, {SolanaNetwork? network, RiskEngine? risk})
      : _decoder = InstructionDecoder(network: network),
        _risk = risk ?? const RiskEngine();

  /// Preview instructions we built ourselves.
  ///
  /// [symbols] maps mint address to ticker, supplied by the caller from
  /// whatever it already holds. The engine never fetches metadata — that
  /// would put a second network call on the approval path.
  Future<TxPreview> preview({
    required List<encoder.Instruction> instructions,
    required List<solana.Ed25519HDKeyPair> signers,
    required String ownerAddress,
    Map<String, String> symbols = const {},
    List<RiskFlag> extraFlags = const [],
  }) async {
    if (signers.isEmpty) {
      return const TxPreview.unverified('No signer available for this transaction.');
    }

    final LatestBlockhash blockhash;
    final encoder.SignedTx probe;
    try {
      final data = await _rpc.getLatestBlockhash();
      blockhash = LatestBlockhash(
        blockhash: data['blockhash'] as String,
        lastValidBlockHeight: data['lastValidBlockHeight'] as int,
      );
      probe = await solana.signTransaction(
        blockhash,
        solana.Message(instructions: instructions),
        signers,
      );
    } catch (e) {
      debugLog('[Preview] could not build probe: $e');
      return const TxPreview.unverified('Could not prepare this transaction for checking.');
    }

    return _previewEncoded(
      encoded: probe.encode(),
      staticKeys: [for (final k in probe.compiledMessage.accountKeys) k.toBase58()],
      // Instructions we built ourselves need no resolving: there are no
      // lookup tables in a message this app compiled.
      raw: [for (final ix in instructions) RawInstruction.from(ix)],
      ownerAddress: ownerAddress,
      symbols: symbols,
      extraFlags: extraFlags,
    );
  }

  /// Preview a transaction somebody else built — a Jupiter route, a merchant's
  /// payload, a dapp request.
  ///
  /// Instruction account indices are resolved against the simulation's own
  /// account list, which already includes everything the address lookup tables
  /// pulled in. This used to go through `decompileMessage()`, whose
  /// `addressLookupTableAccounts` parameter defaults to an empty list — and
  /// the resolver throws on that the moment a message has any table lookups.
  /// So every v0 transaction using a table (which is to say: every Jupiter
  /// route and most dapp requests) decoded to zero instructions, and every
  /// instruction-level risk rule was skipped in silence.
  Future<TxPreview> previewSigned({
    required String base64Tx,
    required String ownerAddress,
    Map<String, String> symbols = const {},
  }) async {
    final encoder.SignedTx tx;
    try {
      tx = encoder.SignedTx.decode(base64Tx);
    } catch (e) {
      debugLog('[Preview] could not decode transaction: $e');
      return const TxPreview.unverified('This transaction could not be read.');
    }

    return _previewEncoded(
      encoded: base64Tx,
      staticKeys: [for (final k in tx.compiledMessage.accountKeys) k.toBase58()],
      compiled: tx.compiledMessage.instructions,
      ownerAddress: ownerAddress,
      symbols: symbols,
      userInitiated: false,
    );
  }

  Future<TxPreview> _previewEncoded({
    required String encoded,
    required List<String> staticKeys,
    required String ownerAddress,
    required Map<String, String> symbols,
    List<RawInstruction>? raw,
    List<encoder.CompiledInstruction>? compiled,
    List<RiskFlag> extraFlags = const [],
    bool userInitiated = true,
  }) async {
    final Map<String, dynamic> sim;
    try {
      sim = await _rpc.simulateTransaction(encoded, innerInstructions: true);
    } catch (e) {
      debugLog('[Preview] simulation failed: $e');
      return const TxPreview.unverified('Could not check this transaction with the network.');
    }

    final keys = _accountKeys(staticKeys, sim);
    final fee = (sim['fee'] as int?) ?? 0;
    final deltas = _deltas(sim, keys, ownerAddress, symbols, fee);

    final resolved = raw ?? _resolve(compiled ?? const [], keys);
    final instructionsUnavailable = resolved == null;
    final decoded = _decoder.decodeRaw(resolved ?? const []);

    final err = sim['err'];
    final logs = ((sim['logs'] as List?) ?? const []).cast<String>();

    final flags = [
      ...extraFlags,
      ..._risk.evaluate(
        instructions: decoded,
        deltas: deltas,
        willFail: err != null,
        instructionsUnavailable: instructionsUnavailable,
        userInitiated: userInitiated,
      ),
    ]..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return TxPreview(
      deltas: deltas,
      flags: flags,
      instructions: decoded,
      feeLamports: fee,
      computeUnits: (sim['unitsConsumed'] as int?) ?? 0,
      willFail: err != null,
      failureReason: err != null ? _humanize(err, logs) : null,
    );
  }

  /// Resolves a compiled message's account indices against [keys].
  ///
  /// Returns null — not an empty list — when an index points past the end of
  /// the key list, which means the simulation did not report every address the
  /// message refers to. An empty list would read as "this transaction does
  /// nothing", which is the most dangerous thing a preview can say.
  List<RawInstruction>? _resolve(
    List<encoder.CompiledInstruction> compiled,
    List<String> keys,
  ) {
    final out = <RawInstruction>[];
    for (final ix in compiled) {
      if (ix.programIdIndex >= keys.length) {
        debugLog('[Preview] program index ${ix.programIdIndex} past ${keys.length} keys');
        return null;
      }
      final accounts = <String>[];
      for (final index in ix.accountKeyIndexes) {
        if (index >= keys.length) {
          debugLog('[Preview] account index $index past ${keys.length} keys');
          return null;
        }
        accounts.add(keys[index]);
      }
      out.add(RawInstruction(
        programId: keys[ix.programIdIndex],
        data: Uint8List.fromList(ix.data.toList()),
        accounts: accounts,
      ));
    }
    return out;
  }

  /// Balance arrays are indexed by the message's account list: the static
  /// keys first, then any addresses pulled in from lookup tables, writable
  /// before readonly.
  List<String> _accountKeys(List<String> staticKeys, Map<String, dynamic> sim) {
    final keys = [...staticKeys];
    final loaded = sim['loadedAddresses'] as Map<String, dynamic>?;
    if (loaded != null) {
      keys.addAll(((loaded['writable'] as List?) ?? const []).cast<String>());
      keys.addAll(((loaded['readonly'] as List?) ?? const []).cast<String>());
    }
    return keys;
  }

  List<BalanceDelta> _deltas(
    Map<String, dynamic> sim,
    List<String> keys,
    String owner,
    Map<String, String> symbols,
    int fee,
  ) {
    final deltas = <BalanceDelta>[
      ..._nativeDeltas(sim, keys, owner, fee),
      ..._tokenDeltas(sim, owner, symbols),
    ];

    // The signer's own movements are what they are deciding about; everything
    // else is context. Within each group, the largest movement leads.
    deltas.sort((a, b) {
      if (a.isOwnAccount != b.isOwnAccount) return a.isOwnAccount ? -1 : 1;
      return b.rawDelta.abs().compareTo(a.rawDelta.abs());
    });
    return deltas;
  }

  List<BalanceDelta> _nativeDeltas(
    Map<String, dynamic> sim,
    List<String> keys,
    String owner,
    int fee,
  ) {
    final pre = (sim['preBalances'] as List?)?.cast<int>();
    final post = (sim['postBalances'] as List?)?.cast<int>();
    if (pre == null || post == null) return const [];

    final out = <BalanceDelta>[];
    final count = [pre.length, post.length, keys.length].reduce((a, b) => a < b ? a : b);
    for (var i = 0; i < count; i++) {
      var delta = post[i] - pre[i];
      // Index 0 is the fee payer and its delta includes the fee. The sheet
      // shows the fee on its own line, so leaving it in would double-count
      // it and make the amount look wrong by exactly the fee.
      if (i == 0) delta += fee;
      if (delta == 0) continue;

      out.add(BalanceDelta(
        mint: null,
        owner: keys[i],
        rawDelta: delta,
        decimals: 9,
        symbol: 'SOL',
        isOwnAccount: keys[i] == owner,
        postRaw: post[i],
      ));
    }
    return out;
  }

  List<BalanceDelta> _tokenDeltas(
    Map<String, dynamic> sim,
    String owner,
    Map<String, String> symbols,
  ) {
    Map<String, Map<String, dynamic>> index(List<dynamic>? entries) => {
          for (final e in (entries ?? const []))
            '${(e as Map)['accountIndex']}|${e['mint']}': Map<String, dynamic>.from(e),
        };

    final pre = index(sim['preTokenBalances'] as List?);
    final post = index(sim['postTokenBalances'] as List?);

    final out = <BalanceDelta>[];
    for (final key in {...pre.keys, ...post.keys}) {
      final before = pre[key];
      final after = post[key];
      final entry = after ?? before!;

      final amountBefore = _amount(before);
      final amountAfter = _amount(after);
      final delta = amountAfter - amountBefore;
      if (delta == BigInt.zero) continue;

      final mint = entry.stringAt('mint');
      if (mint == null) continue;
      final entryOwner = entry.stringAt('owner') ?? '';

      out.add(BalanceDelta(
        mint: mint,
        owner: entryOwner,
        // clamp, not toInt(): a u64 at or above 2^63 wraps to negative here,
        // which flips isIncoming and suppressed the "nothing comes back"
        // rule for every token in the transaction. A scam mint can legally
        // hold a supply that large.
        rawDelta: delta.isValidInt
            ? delta.toInt()
            : (delta.isNegative ? _minInt : _maxInt),
        decimals: entry.mapAt('uiTokenAmount')?.intAt('decimals') ?? 0,
        symbol: symbols[mint],
        isOwnAccount: entryOwner == owner,
      ));
    }
    return out;
  }

  /// Token amounts arrive as decimal strings because a u64 does not fit a
  /// signed int; parsing through BigInt keeps the top of the range intact.
  BigInt _amount(Map<String, dynamic>? entry) {
    final raw = entry?.mapAt('uiTokenAmount')?['amount']?.toString();
    return raw == null ? BigInt.zero : (BigInt.tryParse(raw) ?? BigInt.zero);
  }

  // Saturation bounds for a delta too large to hold in a signed 64-bit int.
  static const _maxInt = 9223372036854775807;
  static const _minInt = -9223372036854775808;

  String _humanize(dynamic err, List<String> logs) {
    final joined = logs.join('\n');
    if (joined.contains('insufficient lamports') || joined.contains('Insufficient Funds')) {
      return 'Not enough SOL to cover this transaction.';
    }
    if (joined.contains('InsufficientFundsForRent')) {
      return 'This would leave an account below the rent-exempt minimum.';
    }
    if (err is Map && err['InstructionError'] is List) {
      final detail = (err['InstructionError'] as List).last;
      if (detail is String) return 'The transaction would fail: $detail.';
      if (detail is Map && detail['Custom'] != null) {
        final line = logs.reversed.firstWhere(
          (l) => l.contains('Error:'),
          orElse: () => '',
        );
        return line.isNotEmpty
            ? 'The program would reject this: ${line.split('Error:').last.trim()}'
            : 'The program would reject this (code ${detail['Custom']}).';
      }
    }
    return 'This transaction would fail.';
  }
}
