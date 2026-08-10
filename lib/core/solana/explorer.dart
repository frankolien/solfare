import 'package:solfare/core/constant/network.dart';

/// Links out to Solana Explorer for the cluster the app is actually on.
class Explorer {
  Explorer._();

  static const _base = 'https://explorer.solana.com';

  // Mainnet is Explorer's default and takes no parameter.
  static String get _cluster => switch (NetworkConstants.current) {
        SolanaNetwork.mainnet => '',
        SolanaNetwork.devnet => '?cluster=devnet',
        SolanaNetwork.testnet => '?cluster=testnet',
      };

  static String tx(String signature) => '$_base/tx/$signature$_cluster';

  static String address(String address) => '$_base/address/$address$_cluster';
}
