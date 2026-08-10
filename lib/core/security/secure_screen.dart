import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Hides the current screen from screenshots, screen recordings, and the OS
/// app-switcher snapshot.
class SecureScreen {
  SecureScreen._();

  static const _iosChannel = MethodChannel('solfare/secure_screen');

  static int _depth = 0;

  /// True while at least one screen is asking for protection.
  static bool get isEnabled => _depth > 0;

  static Future<void> enable() async {
    if (kIsWeb) return;
    final wasOff = _depth == 0;
    _depth++;
    if (wasOff) await _apply(true);
  }

  static Future<void> disable() async {
    if (kIsWeb) return;
    if (_depth == 0) return;
    _depth--;
    if (_depth == 0) await _apply(false);
  }

  static Future<void> _apply(bool on) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (on) {
          await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        } else {
          await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        }
      } on MissingPluginException {
        // Test host without the native handler.
      } on PlatformException {
        // Nothing useful to do; the screen is still rendered either way.
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosChannel.invokeMethod(on ? 'enable' : 'disable');
      } on MissingPluginException {
        // Older build / test host without the native handler — fail open.
      }
    }
  }

  @visibleForTesting
  static void resetForTest() => _depth = 0;
}
