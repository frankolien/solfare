import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Hides the current activity from screenshots and screen recordings on
/// Android by setting FLAG_SECURE. iOS does not expose an equivalent API
/// from Flutter — sensitive screens still appear in the app switcher unless
/// we add a platform channel later.
class SecureScreen {
  static Future<void> enable() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  static Future<void> disable() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }
}
