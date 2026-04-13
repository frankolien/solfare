import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SolanaNetwork {
  mainnet('Mainnet', 'https://api.mainnet-beta.solana.com'),
  testnet('Testnet', 'https://api.testnet.solana.com'),
  devnet('Devnet', 'https://api.devnet.solana.com');

  final String label;
  final String url;
  const SolanaNetwork(this.label, this.url);
}

class NetworkConstants {
  static const _storageKey = 'solana_network';
  static final _storage = const FlutterSecureStorage();

  // Current network — defaults to mainnet, loaded from storage on init
  static SolanaNetwork _current = SolanaNetwork.mainnet;

  static SolanaNetwork get current => _current;
  static String get solanaUrl => _current.url;

  static Future<void> load() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved != null) {
      _current = SolanaNetwork.values.firstWhere(
        (n) => n.name == saved,
        orElse: () => SolanaNetwork.mainnet,
      );
    }
  }

  static Future<void> setNetwork(SolanaNetwork network) async {
    _current = network;
    await _storage.write(key: _storageKey, value: network.name);
  }
}
