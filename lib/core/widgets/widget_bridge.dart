import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Pushes lightweight read-only snapshots into the iOS WidgetKit extension's
// shared UserDefaults via a MethodChannel. The widget extension (separate
// process) reads these on its next timeline refresh.
//
// Keep the payload small — it's read every widget refresh and there's no
// reason for sensitive material to ever cross this boundary. Mnemonics,
// private keys, addresses → never. Display values only.
class WidgetBridge {
  WidgetBridge._();

  static const _channel = MethodChannel('solfare/widget_data');

  static const _kWallet = 'wallet_widget_data';
  static const _kPrice = 'price_widget_data';

  static Future<void> pushWallet({
    required String walletName,
    required double balanceUsd,
    required double percentChange24h,
  }) =>
      _push(_kWallet, {
        'walletName': walletName,
        'balanceUsd': balanceUsd,
        'percentChange24h': percentChange24h,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  static Future<void> pushPrice({
    required String symbol,
    required double priceUsd,
    required double percentChange24h,
    required List<double> sparkline,
  }) =>
      _push(_kPrice, {
        'symbol': symbol,
        'priceUsd': priceUsd,
        'percentChange24h': percentChange24h,
        // Cap sparkline length — the widget renders a tiny chart and the
        // whole payload is serialised as JSON into UserDefaults.
        'sparkline': sparkline.length > 40
            ? sparkline.sublist(sparkline.length - 40)
            : sparkline,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  static Future<void> _push(String key, Map<String, Object?> payload) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final json = jsonEncode(payload);
    try {
      await _channel.invokeMethod('write', {'key': key, 'json': json});
      debugPrint('[WidgetBridge] pushed $key (${json.length}B)');
    } on MissingPluginException catch (e) {
      // Loud during development — if this fires in prod it means the iOS
      // method-channel handler never registered (engine timing bug).
      debugPrint('[WidgetBridge] NO NATIVE HANDLER for $key: $e');
    } catch (e) {
      debugPrint('[WidgetBridge] push $key failed: $e');
    }
  }
}
