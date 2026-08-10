import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live SOL/USDT price stream over Binance's public WebSocket.
class BinancePriceWsService with WidgetsBindingObserver {
  BinancePriceWsService({required this.onTick}) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Fires whenever Binance pushes a fresh ticker frame.
  final void Function(double priceUsd, double percentChange24h) onTick;

  // Public combined-stream endpoint.
  static const _wsUrl = 'wss://stream.binance.com:9443/ws/solusdt@ticker';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _stopped = false;
  bool _started = false;

  Future<void> start() async {
    if (_started && _channel != null) return;
    _started = true;
    _stopped = false;
    await _disconnect();
    _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _started = false;
    await _disconnect();
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_started && _channel == null) {
          _stopped = false;
          _connect();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _disconnect();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _connect() {
    if (_stopped) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel = channel;

      channel.ready.then((_) {
        if (_stopped) return;
        _reconnectAttempts = 0;
        debugLog('[BinanceWS] connected to solusdt@ticker');
      }).catchError((Object e) {
        debugLog('[BinanceWS] handshake failed: $e');
        _scheduleReconnect();
      });

      _sub = channel.stream.listen(
        _handleMessage,
        onError: (Object e) {
          debugLog('[BinanceWS] stream error: $e');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (e) {
      debugLog('[BinanceWS] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      // ticker frame fields per Binance docs: c = last price (string), P = 24h
      // % change (string)
      final price = double.tryParse(msg['c']?.toString() ?? '');
      final change = double.tryParse(msg['P']?.toString() ?? '');
      if (price == null || change == null) return;
      onTick(price, change);
    } catch (_) {
      // Ignore malformed frames — next tick lands in 1s.
    }
  }

  Future<void> _disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _reconnectTimer?.cancel();
    final seconds = [1, 2, 4, 8, 16, 30];
    final delay = seconds[
        _reconnectAttempts < seconds.length ? _reconnectAttempts : seconds.length - 1];
    _reconnectAttempts++;
    debugLog('[BinanceWS] reconnecting in ${delay}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      await _disconnect();
      _connect();
    });
  }
}
