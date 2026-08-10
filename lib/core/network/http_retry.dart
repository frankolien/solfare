import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

// Single retry-with-timeout wrapper used by every outbound HTTP client.
// All call sites should go through this so timeouts and the backoff curve
// stay consistent — bare http.Client calls block forever on a hung socket
// and that's how Bloc handlers get stuck.
class HttpRetry {
  HttpRetry._();

  static const Duration defaultTimeout = Duration(seconds: 12);
  static const int defaultMaxAttempts = 3;
  static const Duration defaultInitialBackoff = Duration(milliseconds: 400);

  // Retries on TimeoutException, SocketException-shaped errors, and 5xx /
  // 429 responses. Returns the final response (success or terminal failure)
  // so the caller still decides how to interpret status codes.
  static Future<http.Response> send(
    Future<http.Response> Function() request, {
    Duration timeout = defaultTimeout,
    int maxAttempts = defaultMaxAttempts,
    Duration initialBackoff = defaultInitialBackoff,
  }) async {
    // Object?, because `catch (e)` binds one — a socket failure can be an
    // Error as easily as an Exception. It is only ever rethrown through the
    // typed wrapper below, so nothing anonymous escapes.
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await request().timeout(timeout);
        if (!_isRetryableStatus(response.statusCode) || attempt == maxAttempts) {
          return response;
        }
        lastError = _StatusError(response.statusCode);
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == maxAttempts) rethrow;
      } catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == maxAttempts) rethrow;
      }
      // Exponential backoff with a small jitter to avoid synchronised retries.
      final backoffMs = initialBackoff.inMilliseconds * pow(2, attempt - 1).toInt();
      final jitterMs = Random().nextInt(100);
      await Future.delayed(Duration(milliseconds: backoffMs + jitterMs));
    }
    // Unreachable — the loop above either returns or throws. Wrapped rather
    // than rethrown raw so a caller can always catch this by type.
    throw HttpRetryException('Request failed after $maxAttempts attempts', lastError);
  }

  static bool _isRetryableStatus(int code) => code == 429 || (code >= 500 && code < 600);

  static bool _isRetryable(Object e) {
    if (e is TimeoutException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Connection') ||
        s.contains('HandshakeException');
  }
}

class _StatusError implements Exception {
  final int statusCode;
  _StatusError(this.statusCode);
  @override
  String toString() => 'HTTP $statusCode';
}

/// Raised when every attempt was used up without a usable response.
///
/// Wraps whatever the last attempt threw so the cause survives, while giving
/// callers a type they can catch — the old code rethrew the raw `Object?`,
/// which no `on ... catch` could name.
class HttpRetryException implements Exception {
  final String message;
  final Object? cause;

  const HttpRetryException(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
