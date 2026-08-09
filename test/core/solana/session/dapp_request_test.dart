import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';

void main() {
  const key = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTt';
  const redirect = 'myapp%3A%2F%2Fcallback';

  DappRequest? parse(String url) => DappRequestParser.parse(Uri.parse(url));

  group('connect', () {
    test('reads a well-formed request', () {
      final request = parse(
        'solfare://v1/connect'
        '?dapp_encryption_public_key=$key'
        '&app_url=https%3A%2F%2Fapp.example.com'
        '&redirect_link=$redirect'
        '&cluster=mainnet-beta',
      );

      expect(request, isA<DappConnectRequest>());
      final connect = request! as DappConnectRequest;
      expect(connect.dappPublicKey, key);
      expect(connect.origin, 'app.example.com');
      expect(connect.cluster, 'mainnet-beta');
      expect(connect.redirectLink.toString(), 'myapp://callback');
    });

    test('an http origin is refused', () {
      // A non-https origin cannot be shown to the user as an identity.
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&app_url=http%3A%2F%2Fapp.example.com'
            '&redirect_link=$redirect'),
        isNull,
      );
    });

    test('a missing origin is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&redirect_link=$redirect'),
        isNull,
      );
    });

    test('a missing encryption key is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?app_url=https%3A%2F%2Fapp.example.com'
            '&redirect_link=$redirect'),
        isNull,
      );
    });
  });

  group('redirect validation', () {
    test('a javascript redirect is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&app_url=https%3A%2F%2Fapp.example.com'
            '&redirect_link=javascript%3Aalert(1)'),
        isNull,
      );
    });

    test('a file redirect is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&app_url=https%3A%2F%2Fapp.example.com'
            '&redirect_link=file%3A%2F%2F%2Fetc%2Fpasswd'),
        isNull,
      );
    });

    test('a redirect with no scheme is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&app_url=https%3A%2F%2Fapp.example.com'
            '&redirect_link=nowhere'),
        isNull,
      );
    });

    test('a request with no redirect at all is refused', () {
      expect(
        parse('solfare://v1/connect'
            '?dapp_encryption_public_key=$key'
            '&app_url=https%3A%2F%2Fapp.example.com'),
        isNull,
      );
    });
  });

  group('sealed requests', () {
    String sealed(String method) => 'solfare://v1/$method'
        '?dapp_encryption_public_key=$key'
        '&redirect_link=$redirect'
        '&nonce=NONCE123'
        '&payload=PAYLOAD456';

    test('signAndSendTransaction', () {
      final request = parse(sealed('signAndSendTransaction'));
      expect(request, isA<DappSignAndSendRequest>());
      expect((request! as DappSealedRequest).nonce, 'NONCE123');
      expect((request as DappSealedRequest).payload, 'PAYLOAD456');
    });

    test('signTransaction', () {
      expect(parse(sealed('signTransaction')), isA<DappSignTransactionRequest>());
    });

    test('signMessage', () {
      expect(parse(sealed('signMessage')), isA<DappSignMessageRequest>());
    });

    test('a sealed request with no payload is refused', () {
      expect(
        parse('solfare://v1/signTransaction'
            '?dapp_encryption_public_key=$key'
            '&redirect_link=$redirect'
            '&nonce=NONCE123'),
        isNull,
      );
    });

    test('a sealed request with no nonce is refused', () {
      expect(
        parse('solfare://v1/signTransaction'
            '?dapp_encryption_public_key=$key'
            '&redirect_link=$redirect'
            '&payload=PAYLOAD456'),
        isNull,
      );
    });
  });

  group('rejection', () {
    test('another app\'s scheme is not ours to handle', () {
      expect(parse('phantom://v1/connect?dapp_encryption_public_key=$key'), isNull);
    });

    test('an unknown method is refused rather than guessed at', () {
      expect(
        parse('solfare://v1/drainWallet'
            '?dapp_encryption_public_key=$key'
            '&redirect_link=$redirect'),
        isNull,
      );
    });

    test('an unversioned path is refused', () {
      expect(
        parse('solfare://connect'
            '?dapp_encryption_public_key=$key'
            '&redirect_link=$redirect'),
        isNull,
      );
    });

    test('the internal navigation links are not dapp requests', () {
      // solfare://send and friends already exist for in-app navigation and
      // must not be mistaken for a signing request.
      expect(parse('solfare://send'), isNull);
      expect(parse('solfare://swap'), isNull);
    });
  });

  group('replies', () {
    test('adds parameters without dropping the dapp\'s own', () {
      final url = DappRequestParser.reply(
        Uri.parse('myapp://callback?state=xyz'),
        {'nonce': 'N', 'data': 'D'},
      );

      expect(url.queryParameters['state'], 'xyz');
      expect(url.queryParameters['nonce'], 'N');
      expect(url.queryParameters['data'], 'D');
    });
  });
}
