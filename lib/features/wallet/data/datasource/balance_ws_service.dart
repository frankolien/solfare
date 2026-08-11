import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Maintains a Solana JSON-RPC WebSocket subscription to a single account's
/// balance changes via `accountSubscribe`.
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

  Future<void> watch(String address) async {
    if (_currentAddress == address && _channel != null) return;
    _stopped = false;
    _currentAddress = address;
    await _disconnect();
    _connect();
  }

  /// Stop watching and close the socket.
  Future<void> stop() async {
    _stopped = true;
    _currentAddress = null;
    await _disconnect();
  }

  /// Fully tear down, including the lifecycle observer.
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

      // `channel.ready` resolves once the WS handshake succeeds or errors.
      channel.ready.then((_) {
        if (_stopped) return;
        _send({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'accountSubscribe',
          'params': [
            _currentAddress,
            {'encoding': 'jsonParsed', 'commitment': 'confirmed'},
          ],
        });
        debugLog('[WS] connected, subscribing to $_currentAddress');
      }).catchError((Object e) {
        debugLog('[WS] handshake failed: $e');
        _scheduleReconnect();
      });

      _sub = channel.stream.listen(
        _handleMessage,
        onError: (Object e) {
          debugLog('[WS] stream error: $e');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );

      // Helius closes idle sockets after ~60s — ping every 30s.
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _send({'jsonrpc': '2.0', 'id': 999, 'method': 'ping'});
      });
    } catch (e) {
      debugLog('[WS] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;

      if (msg['id'] == 1 && msg['result'] is int) {
        _subscriptionId = msg['result'] as int;
        _reconnectAttempts = 0; // successful handshake resets backoff
        debugLog('[WS] subscribed, id=$_subscriptionId');
        // On connect, not only on change. Notifications arrive when the
        // balance moves, so a reconnect on its own never re-read it — a cold
        // start whose fetch failed stayed stale until something happened on
        // chain. Reconnecting is now itself a reason to refresh.
        onChange();
        return;
      }

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
