import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/network/network_error.dart';

void main() {
  test('the failure the user actually hits reads as no internet', () {
    // Verbatim from the device, which is what reached the screen before.
    const raw = "Exception: Failed to get balance: ClientException with "
        "SocketException: Failed host lookup: 'api.devnet.solana.com' "
        "(OS Error: nodename nor servname provided, or not known, errno = 8), "
        "uri=https://api.devnet.solana.com";

    expect(friendlyNetworkError(raw), 'No internet connection.');
  });

  test('typed socket and timeout failures are named', () {
    expect(friendlyNetworkError(const SocketException('nope')),
        'No internet connection.');
    expect(friendlyNetworkError(TimeoutException('slow')),
        'The network is taking too long. Try again.');
  });

  test('rate limiting and server trouble are told apart', () {
    expect(friendlyNetworkError('HTTP 429 Too Many Requests'),
        contains('Too many requests'));
    expect(friendlyNetworkError('HTTP 503 Service Unavailable'),
        contains('having trouble'));
  });

  test('an unrecognised failure still says something a person can read', () {
    final text = friendlyNetworkError(StateError('kaboom'));

    expect(text, 'Could not reach the network. Try again in a moment.');
    expect(text, isNot(contains('kaboom')));
  });

  test('no message leaks a host, a path or an errno', () {
    const raw = "SocketException: Failed host lookup: 'api.devnet.solana.com' "
        "(OS Error: errno = 8), uri=https://mainnet.helius-rpc.com/?api-key=SECRET";
    final text = friendlyNetworkError(raw);

    for (final leak in ['helius', 'api-key', 'SECRET', 'errno', 'devnet']) {
      expect(text.toLowerCase(), isNot(contains(leak.toLowerCase())));
    }
  });
}
