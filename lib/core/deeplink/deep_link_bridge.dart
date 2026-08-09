import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';
import 'package:solfare/core/util/app_log.dart';

// Receives solfare:// URLs from the native side (AppDelegate forwards them
// via MethodChannel) and translates them into router navigations.
//
// Recognised hosts: send | swap | receive | stake | market.
// Anything else falls through to the homepage.
class DeepLinkBridge {
  DeepLinkBridge._();

  static const _channel = MethodChannel('solfare/deeplink');

  // Last intent received but not yet consumed by a screen. Surfaces here
  // because GoRouter doesn't carry custom intent state across navigations
  // and the existing send/swap routes need wallet data the widget can't
  // supply. The HomepageScreen can watch this notifier to flip tabs or
  // open sheets when an intent arrives while it's already in view.
  static final ValueNotifier<String?> intent = ValueNotifier<String?>(null);

  static GoRouter? _router;

  static void init(GoRouter router) {
    _router = router;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'open') return null;
      final raw = call.arguments as String?;
      if (raw == null) return null;
      _handle(raw);
      return null;
    });
  }

  /// A dapp request that arrived and has not been shown to the user yet.
  /// Separate from [intent] because these are not navigation — they are
  /// somebody asking for a signature, and they get their own approval sheet.
  static final ValueNotifier<DappRequest?> dappRequest = ValueNotifier<DappRequest?>(null);

  static void _handle(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'solfare') return;

    // v1/* is the dApp Connect surface. Checked before the navigation hosts
    // so a signing request can never be mistaken for "open the send screen".
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
    // Route everything to the homepage for now. The screen reads `intent`
    // on mount / on change and decides what to surface.
    _router?.go(AppRoutes.homepage);
  }

  // Test-only seam.
  @visibleForTesting
  static void handleForTest(String raw) => _handle(raw);
}
