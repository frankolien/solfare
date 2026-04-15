import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  static String get _heliusApiKey => dotenv.env['HELIUS_API_KEY'] ?? '';

  // Listeners fired on network switch so services (WS etc.) can reconnect.
  static final List<void Function(SolanaNetwork)> _listeners = [];

  static void addListener(void Function(SolanaNetwork) cb) => _listeners.add(cb);
  static void removeListener(void Function(SolanaNetwork) cb) => _listeners.remove(cb);

  // Current network — defaults to mainnet, loaded from storage on init
  static SolanaNetwork _current = SolanaNetwork.mainnet;

  static SolanaNetwork get current => _current;
  static String get solanaUrl => _current.url;

  // Helius DAS endpoint — supports getAssetsByOwner (regular + compressed NFTs).
  // Helius only serves mainnet and devnet; testnet falls back to mainnet DAS.
  static String get heliusDasUrl {
    final cluster = _current == SolanaNetwork.devnet ? 'devnet' : 'mainnet';
    return 'https://$cluster.helius-rpc.com/?api-key=$_heliusApiKey';
  }

  /// Helius WebSocket endpoint for live `accountSubscribe` streams.
  static String get heliusWsUrl {
    final cluster = _current == SolanaNetwork.devnet ? 'devnet' : 'mainnet';
    return 'wss://$cluster.helius-rpc.com/?api-key=$_heliusApiKey';
  }

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
    if (_current == network) return;
    _current = network;
    await _storage.write(key: _storageKey, value: network.name);
    for (final cb in List.of(_listeners)) {
      try {
        cb(network);
      } catch (_) {}
    }
  }
}
