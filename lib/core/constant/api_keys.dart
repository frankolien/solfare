import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:solfare/core/util/app_log.dart';

/// Third-party API keys, resolved at build time rather than shipped as an
/// asset.
class ApiKeys {
  ApiKeys._();

  static const _heliusDefine = String.fromEnvironment('HELIUS_API_KEY');
  static const _jupiterDefine = String.fromEnvironment('JUPITER_API_KEY');

  static String get helius => _resolve(_heliusDefine, 'HELIUS_API_KEY');
  static String get jupiter => _resolve(_jupiterDefine, 'JUPITER_API_KEY');

  static String _resolve(String define, String name) {
    if (define.isNotEmpty) return define;
    final fallback = _localEnv[name];
    if (fallback != null && fallback.isNotEmpty) return fallback;
    debugLog('[ApiKeys] $name is not set — pass --dart-define=$name=...');
    return '';
  }

  static Map<String, String> _localEnv = const {};

  /// Reads a `.env` if the build happens to bundle one.
  static Future<void> loadLocalEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      _localEnv = Map<String, String>.from(dotenv.env);
    } catch (_) {
      // Expected whenever .env is not bundled, which is the intended state.
    }
  }
}
