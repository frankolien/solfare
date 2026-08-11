import 'dart:async';
import 'dart:io';

/// What to tell the user when a request did not come back.
///
/// Raw exceptions reached the screen verbatim — "ClientException with
/// SocketException: Failed host lookup: 'api.devnet.solana.com' (OS Error:
/// nodename nor servname provided, errno = 8)" is a stack trace wearing a
/// snackbar, and it names internal hosts to anyone standing nearby.
String friendlyNetworkError(Object error) {
  if (error is SocketException) return _offline;
  if (error is TimeoutException) return _slow;

  final text = error.toString().toLowerCase();

  // http's ClientException wraps the cause in its message rather than keeping
  // it as a typed error, so the type check above misses the common case.
  if (text.contains('failed host lookup') ||
      text.contains('socketexception') ||
      text.contains('network is unreachable') ||
      text.contains('no address associated') ||
      text.contains('connection refused') ||
      text.contains('connection closed')) {
    return _offline;
  }
  if (text.contains('timeout') || text.contains('timed out')) return _slow;
  if (text.contains('429') || text.contains('too many requests')) {
    return 'Too many requests right now. Try again in a moment.';
  }
  if (text.contains('500') ||
      text.contains('502') ||
      text.contains('503') ||
      text.contains('504')) {
    return 'The network is having trouble. Try again in a moment.';
  }

  return 'Could not reach the network. Try again in a moment.';
}

const _offline = 'No internet connection.';
const _slow = 'The network is taking too long. Try again.';
