import 'package:solfare/core/constant/network.dart';

/// Which clusters an entry is valid on.
enum ProgramScope { anyCluster, mainnetOnly }

class KnownProgram {
  final String id;
  final String name;
  final ProgramScope scope;

  /// Ships with the runtime.
  final bool isCore;

  const KnownProgram(this.id, this.name, {this.scope = ProgramScope.anyCluster, this.isCore = false});
}

/// Address to human name, bundled rather than fetched.
class ProgramRegistry {
  const ProgramRegistry._();

  static const List<KnownProgram> entries = [
    KnownProgram('11111111111111111111111111111111', 'System Program', isCore: true),
    KnownProgram('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA', 'Token Program', isCore: true),
    KnownProgram('TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb', 'Token-2022', isCore: true),
    KnownProgram('ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL', 'Associated Token Account', isCore: true),
    KnownProgram('ComputeBudget111111111111111111111111111111', 'Compute Budget', isCore: true),
    KnownProgram('Stake11111111111111111111111111111111111111', 'Stake Program', isCore: true),
    KnownProgram('Vote111111111111111111111111111111111111111', 'Vote Program', isCore: true),
    KnownProgram('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr', 'Memo', isCore: true),
    KnownProgram('Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo', 'Memo (v1)', isCore: true),
    KnownProgram('BPFLoaderUpgradeab1e11111111111111111111111', 'Upgradeable Loader', isCore: true),

    KnownProgram('JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4', 'Jupiter Aggregator',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s', 'Metaplex Token Metadata',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc', 'Orca Whirlpool',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8', 'Raydium AMM',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK', 'Raydium CLMM',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('pAMMBay6oceH9fJKBRHGP5D4bD4sWpmSwMn52FMfXEA', 'Pump AMM',
        scope: ProgramScope.mainnetOnly),
    KnownProgram('LBUZKhRxPF3XUpBCjp4YzTKgLccjZhTSDM9YuVaPwxo', 'Meteora DLMM',
        scope: ProgramScope.mainnetOnly),
  ];

  static final Map<String, KnownProgram> _byId = {
    for (final entry in entries) entry.id: entry,
  };

  /// The entry for [programId], or null when we do not recognise it on the
  /// cluster the wallet is pointed at.
  static KnownProgram? lookup(String programId, {SolanaNetwork? network}) {
    final entry = _byId[programId];
    if (entry == null) return null;
    if (entry.scope == ProgramScope.anyCluster) return entry;

    final cluster = network ?? NetworkConstants.current;
    return cluster == SolanaNetwork.mainnet ? entry : null;
  }

  static String? nameFor(String programId, {SolanaNetwork? network}) =>
      lookup(programId, network: network)?.name;

  static bool isCore(String programId) => _byId[programId]?.isCore ?? false;
}
