import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:solfare/core/util/app_log.dart';

/// Third-party API keys, resolved at build time rather than shipped as an
/// asset.
///
/// `.env` used to be listed under `flutter: assets:`, which put it inside the
/// IPA and the APK as a plain file — `unzip -p Solfare.ipa
/// 'Payload/*/flutter_assets/.env'` returned the key. `.gitignore` kept it out
/// of the repository, which is correct and also beside the point: every user's
/// copy of the app carried it.
///
/// A `--dart-define` is compiled into the binary and is still extractable by
/// anyone determined enough — nothing shipped to a device is a secret. The
/// difference is that this one is per-build, so it can be rotated, scoped, and
/// kept out of the source tree, and a debug key never becomes the production
/// key by accident.
///
///   flutter run   --dart-define=HELIUS_API_KEY=...  --dart-define=JUPITER_API_KEY=...
///   flutter build --dart-define=HELIUS_API_KEY=...  --dart-define=JUPITER_API_KEY=...
///
/// For local development, `dotenv` is still consulted as a fallback so an
/// existing `.env` keeps working — see [loadLocalEnv].
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
  ///
  /// Deliberately best-effort: the file is no longer a declared asset, so on
  /// any build that did not opt into shipping it this does nothing at all and
  /// the `--dart-define` values are the only source.
  static Future<void> loadLocalEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      _localEnv = Map<String, String>.from(dotenv.env);
    } catch (_) {
      // Expected whenever .env is not bundled, which is the intended state.
    }
  }
}
