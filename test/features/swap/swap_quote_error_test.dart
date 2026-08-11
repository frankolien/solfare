import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfare/features/swap/data/datasource/jupiter_datasource.dart';
import 'package:solfare/features/swap/domain/swap_executor.dart';

void main() {
  const sol = 'So11111111111111111111111111111111111111112';
  const usdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  Future<Map<String, dynamic>> quoteWith(http.Response response) {
    final source = JupiterDataSource(
      client: MockClient((_) async => response),
    );
    return source.getQuote(
      inputMint: sol,
      outputMint: usdc,
      amount: 1000000000,
    );
  }

  test('an unroutable pair carries Jupiter\'s own sentence', () async {
    // Verbatim from the API: it answers HTTP 200 with the reason in the body,
    // so reading only the status code threw the explanation away.
    expect(
      () => quoteWith(http.Response(
          jsonEncode({'error': 'Swapping of jlWSOL is not supported'}), 200)),
      throwsA(isA<SwapUnavailableException>().having(
        (e) => e.message,
        'message',
        'Swapping of jlWSOL is not supported',
      )),
    );
  });

  test('a non-200 with a reason uses the reason', () async {
    expect(
      () => quoteWith(
          http.Response(jsonEncode({'error': 'Amount too small'}), 400)),
      throwsA(isA<SwapUnavailableException>()
          .having((e) => e.message, 'message', 'Amount too small')),
    );
  });

  test('a non-200 with no reason still says something', () async {
    expect(
      () => quoteWith(http.Response('<html>bad gateway</html>', 502)),
      throwsA(isA<SwapUnavailableException>()
          .having((e) => e.message, 'message', contains('502'))),
    );
  });

  test('no configured key means no key header, not an empty one', () async {
    // Measured against the live API: no header answers 200, the header present
    // and empty answers 401. An empty key is "no key", so the header has to
    // disappear rather than be sent blank.
    Map<String, String>? sent;
    final source = JupiterDataSource(
      client: MockClient((request) async {
        sent = request.headers;
        return http.Response(jsonEncode({'outAmount': '1'}), 200);
      }),
    );

    await source.getQuote(inputMint: sol, outputMint: usdc, amount: 1);

    final keys = sent!.keys.map((k) => k.toLowerCase());
    expect(keys, isNot(contains('x-api-key')));
  });

  test('a good order comes back whole', () async {
    final json = await quoteWith(http.Response(
        jsonEncode({'outAmount': '12345', 'requestId': 'abc'}), 200));

    expect(json['outAmount'], '12345');
  });
}
