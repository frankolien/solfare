import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Hides the current screen from screenshots, screen recordings, and the
/// OS app-switcher snapshot.
///
/// Android uses `FLAG_SECURE`, which covers screenshots, screen recording
/// and the recents thumbnail. iOS has no equivalent — screenshots and screen
/// recordings of an app cannot be prevented — so the `MethodChannel` here
/// buys exactly one thing: a privacy overlay painted over the key window
/// when the app loses focus, which is the app-switcher snapshot.
///
/// Refcounted. It used to be a single flag, and screens nest: the confirm
/// step is pushed *on top of* the screen still displaying the twelve words,
/// so backing out of it called disable() and left the seed behind it
/// screenshot-able.
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
      // Wrapped like the iOS branch: an unhandled throw here left FLAG_SECURE
      // silently absent, and nothing awaits these calls.
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
