import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Maintains a Solana JSON-RPC WebSocket subscription to a single account's
/// balance changes via `accountSubscribe`. When the server pushes a change,
/// [onChange] fires and the caller is expected to re-fetch via HTTP.
///
/// Design choices:
///   - Single subscription (just the native SOL account). Token accounts
///     would multiply the cost and complexity.
///   - Exponential backoff on reconnect: 1s → 2s → 4s → 8s → 16s → 30s cap.
///   - 30-second ping keepalive so Helius doesn't close the idle socket.
///   - Silent failures — this is a nice-to-have overlay on top of manual
///     refresh. It never throws to the UI or shows errors.
class BalanceWsService with WidgetsBindingObserver {
  BalanceWsService({required this.onChange}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final void Function() onChange;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentAddress;
  int _subscriptionId = 0;
  int _reconnectAttempts = 0;
  bool _stopped = false;

  /// Start watching [address]. If already watching the same address, no-op.
  /// Switches targets if called with a different one.
  Future<void> watch(String address) async {
    if (_currentAddress == address && _channel != null) return;
    _stopped = false;
    _currentAddress = address;
    await _disconnect();
    _connect();
  }

  /// Stop watching and close the socket. Call from bloc.close() — after this
  /// the service will not auto-reconnect on lifecycle events either.
  Future<void> stop() async {
    _stopped = true;
    _currentAddress = null;
    await _disconnect();
  }

  /// Fully tear down, including the lifecycle observer. Call on bloc.close.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stop();
  }

  /// Force a reconnect (e.g. network switch, app resumed from background).
  Future<void> reconnect() async {
    if (_currentAddress == null) return;
    await _disconnect();
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // User came back — re-establish the live stream.
        if (_currentAddress != null && _channel == null) {
          _stopped = false;
          _connect();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Free the socket while backgrounded to save battery + credits.
        _disconnect();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _connect() {
    if (_stopped || _currentAddress == null) return;
    final url = NetworkConstants.heliusWsUrl;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _sub = channel.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );

      // Fire accountSubscribe.
      _send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'accountSubscribe',
        'params': [
          _currentAddress,
          {'encoding': 'jsonParsed', 'commitment': 'confirmed'},
        ],
      });

      // Helius closes idle sockets after ~60s — ping every 30s.
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _send({'jsonrpc': '2.0', 'id': 999, 'method': 'ping'});
      });

      debugLog('[WS] connected, subscribing to $_currentAddress');
    } catch (e) {
      debugLog('[WS] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;

      // Confirmation of subscribe — store the subscription id.
      if (msg['id'] == 1 && msg['result'] is int) {
        _subscriptionId = msg['result'] as int;
        _reconnectAttempts = 0; // successful handshake resets backoff
        debugLog('[WS] subscribed, id=$_subscriptionId');
        return;
      }

      // Push notification.
      if (msg['method'] == 'accountNotification') {
        debugLog('[WS] accountNotification — triggering balance refetch');
        onChange();
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _subscriptionId = 0;
  }

  void _scheduleReconnect() {
    if (_stopped || _currentAddress == null) return;
    _reconnectTimer?.cancel();

    // Exponential backoff capped at 30s.
    final seconds = [1, 2, 4, 8, 16, 30];
    final delay = seconds[
        _reconnectAttempts < seconds.length ? _reconnectAttempts : seconds.length - 1];
    _reconnectAttempts++;
    debugLog('[WS] reconnecting in ${delay}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      await _disconnect();
      _connect();
    });
  }
}
