import 'dart:math' as math;

import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// How aggressively to bid for block space.
enum FeeLevel {
  economy(0.50),

  /// The default — lands during normal congestion.
  normal(0.75),

  /// For swaps, where a late fill is a worse fill.
  turbo(0.95);

  final double percentile;
  const FeeLevel(this.percentile);
}

/// Prices the priority fee from what recent blocks charged for the accounts
/// a transaction touches. Solana's fee market is per-account — writing to a
/// busy AMM pool costs more than writing to an idle account — so bidding off
/// `getRecentPrioritizationFees` for that account set avoids both overpaying
/// on quiet accounts and underbidding on hot ones.
class PriorityFeeOracle {
  final SolanaRpcDataSource _rpc;

  const PriorityFeeOracle(this._rpc);

  // Bid this much even when every recent slot reported zero: a tx with no
  // priority fee sorts below every one that has any, and it costs ~0.00002
  // SOL at 200k CU.
  static const int _floorMicroLamports = 100;

  /// Ceiling on the priority component whatever the market says — a congested
  /// pool can report six-figure micro-lamport bids.
  static const int maxPriorityLamports = 5000000; // 0.005 SOL

  /// Micro-lamports per compute unit to bid for a tx writing to
  /// [writableAccounts] at a limit of [computeUnitLimit].
  Future<int> microLamportsPerCu({
    required List<String> writableAccounts,
    required int computeUnitLimit,
    FeeLevel level = FeeLevel.normal,
  }) async {
    final samples = await _rpc.getRecentPrioritizationFees(writableAccounts);

    // Zero-fee slots mean the block had room, not that entry was free.
    // Including them drags the percentile to zero during the congestion
    // we're pricing for.
    final paid = samples.where((f) => f > 0).toList()..sort();

    final bid = paid.isEmpty
        ? _floorMicroLamports
        : math.max(_percentile(paid, level.percentile), _floorMicroLamports);

    final capped = _capToMaxLamports(bid, computeUnitLimit);
    debugLog(
      '[Fee] ${paid.length}/${samples.length} paid slots, ${level.name} '
      'p${(level.percentile * 100).round()} = $bid -> $capped uLamports/CU '
      '(${lamportsFor(capped, computeUnitLimit)} lamports)',
    );
    return capped;
  }

  /// Linear-interpolation percentile over a pre-sorted list.
  int _percentile(List<int> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final position = p * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final weight = position - lower;
    return (sorted[lower] * (1 - weight) + sorted[upper] * weight).round();
  }

  /// Clamp the bid so the total stays under [maxPriorityLamports].
  int _capToMaxLamports(int microLamports, int computeUnitLimit) {
    if (computeUnitLimit <= 0) return microLamports;
    if (lamportsFor(microLamports, computeUnitLimit) <= maxPriorityLamports) {
      return microLamports;
    }
    return (maxPriorityLamports * 1000000) ~/ computeUnitLimit;
  }

  /// What a bid of [microLamports] per CU costs at [computeUnitLimit]. The
  /// runtime charges on the limit, not on units consumed.
  static int lamportsFor(int microLamports, int computeUnitLimit) =>
      (microLamports * computeUnitLimit + 999999) ~/ 1000000;
}
