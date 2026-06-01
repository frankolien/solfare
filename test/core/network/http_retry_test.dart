import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:solfare/core/network/http_retry.dart';

void main() {
  group('HttpRetry', () {
    test('returns the first response when it is a 2xx', () async {
      var calls = 0;
      final response = await HttpRetry.send(() async {
        calls++;
        return http.Response('ok', 200);
      });
      expect(response.statusCode, equals(200));
      expect(calls, equals(1));
    });

    test('retries on 503 and returns once the call succeeds', () async {
      var calls = 0;
      final response = await HttpRetry.send(
        () async {
          calls++;
          if (calls < 2) return http.Response('boom', 503);
          return http.Response('ok', 200);
        },
        initialBackoff: const Duration(milliseconds: 1),
      );
      expect(response.statusCode, equals(200));
      expect(calls, equals(2));
    });

    test('retries on 429 (rate-limit)', () async {
      var calls = 0;
      final response = await HttpRetry.send(
        () async {
          calls++;
          if (calls < 3) return http.Response('throttled', 429);
          return http.Response('ok', 200);
        },
        initialBackoff: const Duration(milliseconds: 1),
      );
      expect(response.statusCode, equals(200));
      expect(calls, equals(3));
    });

    test('does not retry 4xx other than 429 — returns it immediately', () async {
      var calls = 0;
      final response = await HttpRetry.send(
        () async {
          calls++;
          return http.Response('bad request', 400);
        },
        initialBackoff: const Duration(milliseconds: 1),
      );
      expect(response.statusCode, equals(400));
      expect(calls, equals(1));
    });

    test('gives up after maxAttempts and returns the last response', () async {
      var calls = 0;
      final response = await HttpRetry.send(
        () async {
          calls++;
          return http.Response('still 503', 503);
        },
        maxAttempts: 3,
        initialBackoff: const Duration(milliseconds: 1),
      );
      expect(response.statusCode, equals(503));
      expect(calls, equals(3));
    });

    test('times out a hung request and rethrows TimeoutException', () async {
      expect(
        () => HttpRetry.send(
          () => Future.delayed(const Duration(seconds: 5))
              .then((_) => http.Response('late', 200)),
          timeout: const Duration(milliseconds: 50),
          maxAttempts: 1,
          initialBackoff: const Duration(milliseconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
