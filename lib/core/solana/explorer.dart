import 'package:solfare/core/constant/network.dart';

/// Links out to Solana Explorer for the cluster the app is actually on.
///
/// Six screens built this URL by hand, and all six ended in
/// `?cluster=devnet` while the app defaults to mainnet. A user sent SOL,
/// tapped "View on Explorer", and Explorer told them the signature did not
/// exist — the strongest possible signal that their money had vanished.
class Explorer {
  Explorer._();

  static const _base = 'https://explorer.solana.com';

  // Mainnet is Explorer's default and takes no parameter. Naming it anyway
  // would work, but the query is what made the old links wrong, so the
  // shortest correct URL is the one worth producing.
  static String get _cluster => switch (NetworkConstants.current) {
        SolanaNetwork.mainnet => '',
        SolanaNetwork.devnet => '?cluster=devnet',
        SolanaNetwork.testnet => '?cluster=testnet',
      };

  static String tx(String signature) => '$_base/tx/$signature$_cluster';

  static String address(String address) => '$_base/address/$address$_cluster';
}
