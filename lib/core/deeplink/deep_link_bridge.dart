import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';
import 'package:solfare/core/util/app_log.dart';

// Receives solfare:// URLs from the native side (AppDelegate forwards them via
// MethodChannel) and translates them into router navigations.
class DeepLinkBridge {
  DeepLinkBridge._();

  static const _channel = MethodChannel('solfare/deeplink');

  // Last intent received but not yet consumed by a screen.
  static final ValueNotifier<String?> intent = ValueNotifier<String?>(null);

  static GoRouter? _router;

  static void init(GoRouter router) {
    _router = router;
    AppLock.instance.addListener(_flushWhenUnlocked);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'open') return null;
      final raw = call.arguments as String?;
      if (raw == null) return null;
      _handle(raw);
      return null;
    });
  }

  // A URL that arrived while the app was locked.
  static String? _deferred;

  static void _flushWhenUnlocked() {
    if (AppLock.instance.isLocked) return;
    final raw = _deferred;
    if (raw == null) return;
    _deferred = null;
    _handle(raw);
  }

  /// A dapp request that arrived and has not been shown to the user yet.
  static final ValueNotifier<DappRequest?> dappRequest = ValueNotifier<DappRequest?>(null);

  static void _handle(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'solfare') return;

    // Hold everything while the app is locked.
    if (AppLock.instance.isLocked) {
      debugLog('[DeepLink] deferred until unlock: ${uri.host}${uri.path}');
      _deferred = raw;
      _router?.go(AppRoutes.unlockPasscode);
      return;
    }

    // v1/* is the dApp Connect surface.
    final request = DappRequestParser.parse(uri);
    if (request != null) {
      debugLog('[DeepLink] dapp request: ${uri.host}${uri.path}');
      dappRequest.value = request;
      _router?.go(AppRoutes.homepage);
      return;
    }

    final host = uri.host;
    debugLog('[DeepLink] $raw → $host');
    intent.value = host;
    // Route everything to the homepage for now.
    _router?.go(AppRoutes.homepage);
  }

  /// A URL that reached the app by a path other than the method channel — the
  /// router's exception handler, for instance.
  static void handleExternal(String raw) => _handle(raw);

  // Test-only seam.
  @visibleForTesting
  static void handleForTest(String raw) => _handle(raw);
}
