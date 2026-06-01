import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Hides the current screen from screenshots, screen recordings, and the
/// OS app-switcher snapshot.
///
/// Android uses `FLAG_SECURE`. iOS routes through a `MethodChannel` to a
/// Swift handler in AppDelegate that paints a privacy overlay on the key
/// window when the app loses focus.
class SecureScreen {
  SecureScreen._();

  static const _iosChannel = MethodChannel('solfare/secure_screen');

  static Future<void> enable() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosChannel.invokeMethod('enable');
      } on MissingPluginException {
        // Older build / test host without the native handler — fail open.
      }
    }
  }

  static Future<void> disable() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosChannel.invokeMethod('disable');
      } on MissingPluginException {
        // Older build / test host without the native handler — fail open.
      }
    }
  }
}
