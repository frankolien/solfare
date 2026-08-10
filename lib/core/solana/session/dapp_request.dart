/// A request arriving from a dapp over the deeplink scheme.
///
/// Everything here came from outside the app and is untrusted until checked.
sealed class DappRequest {
  /// The dapp's x25519 public key, base58 — also the session identifier.
  final String dappPublicKey;

  /// Where the answer goes. Validated at parse: without it there is nobody
  /// to answer, and with a bad one the answer goes to the wrong place.
  final Uri redirectLink;

  const DappRequest({required this.dappPublicKey, required this.redirectLink});
}

/// The opening handshake. No session exists yet, so this one is not encrypted.
class DappConnectRequest extends DappRequest {
  /// The dapp's https origin. Its host is the only identity the user gets.
  final Uri appUrl;
  final String? cluster;

  const DappConnectRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required this.appUrl,
    this.cluster,
  });

  String get origin => appUrl.host;
}

/// Any request that arrives sealed against an existing session.
sealed class DappSealedRequest extends DappRequest {
  final String nonce;
  final String payload;

  const DappSealedRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required this.nonce,
    required this.payload,
  });
}

class DappSignAndSendRequest extends DappSealedRequest {
  const DappSignAndSendRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required super.nonce,
    required super.payload,
  });
}

class DappSignTransactionRequest extends DappSealedRequest {
  const DappSignTransactionRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required super.nonce,
    required super.payload,
  });
}

class DappSignMessageRequest extends DappSealedRequest {
  const DappSignMessageRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required super.nonce,
    required super.payload,
  });
}

class DappDisconnectRequest extends DappRequest {
  /// The token handed out at connect time, echoed back.
  ///
  /// Disconnect carries no ciphertext, so this is the only thing that proves
  /// the sender is the dapp rather than anyone who read its public key out of
  /// a connect URL. Without it, any app could silently revoke a session.
  final String sessionToken;

  const DappDisconnectRequest({
    required super.dappPublicKey,
    required super.redirectLink,
    required this.sessionToken,
  });
}

/// Parses `solfare://v1/...` URLs into typed requests.
///
/// Rejects rather than repairs. A malformed request from a dapp is either a
/// bug on their side or an attempt on ours, and guessing what was meant is
/// how a wallet ends up signing something nobody asked for.
class DappRequestParser {
  const DappRequestParser._();

  static const scheme = 'solfare';

  /// Error codes mirroring the convention dapps already handle.
  static const int errorUserRejected = 4001;
  static const int errorUnauthorized = 4100;
  static const int errorInvalidRequest = 4200;

  static DappRequest? parse(Uri uri) {
    if (uri.scheme != scheme) return null;

    // Accept both solfare://v1/connect and solfare:/v1/connect shapes, since
    // platforms differ on whether the first segment lands in the host.
    final segments = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (segments.length < 2 || segments.first != 'v1') return null;

    final method = segments[1];
    final params = uri.queryParameters;

    final dappPublicKey = params['dapp_encryption_public_key'];
    final redirect = _validRedirect(params['redirect_link']);
    if (dappPublicKey == null || dappPublicKey.isEmpty || redirect == null) return null;

    switch (method) {
      case 'connect':
        final appUrl = Uri.tryParse(params['app_url'] ?? '');
        // An origin that is not https is not an identity we can show.
        if (appUrl == null || appUrl.scheme != 'https' || appUrl.host.isEmpty) return null;
        return DappConnectRequest(
          dappPublicKey: dappPublicKey,
          redirectLink: redirect,
          appUrl: appUrl,
          cluster: params['cluster'],
        );

      case 'disconnect':
        final token = params['session'];
        if (token == null || token.isEmpty) return null;
        return DappDisconnectRequest(
          dappPublicKey: dappPublicKey,
          redirectLink: redirect,
          sessionToken: token,
        );

      case 'signAndSendTransaction':
      case 'signTransaction':
      case 'signMessage':
        final nonce = params['nonce'];
        final payload = params['payload'];
        if (nonce == null || nonce.isEmpty || payload == null || payload.isEmpty) return null;

        return switch (method) {
          'signAndSendTransaction' => DappSignAndSendRequest(
              dappPublicKey: dappPublicKey,
              redirectLink: redirect,
              nonce: nonce,
              payload: payload,
            ),
          'signTransaction' => DappSignTransactionRequest(
              dappPublicKey: dappPublicKey,
              redirectLink: redirect,
              nonce: nonce,
              payload: payload,
            ),
          _ => DappSignMessageRequest(
              dappPublicKey: dappPublicKey,
              redirectLink: redirect,
              nonce: nonce,
              payload: payload,
            ),
        };

      default:
        return null;
    }
  }

  // A redirect has to be somewhere a reply can go and nowhere dangerous.
  // javascript: and file: are the obvious ones; anything without a scheme
  // cannot be launched at all.
  static Uri? _validRedirect(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.isEmpty) return null;

    const forbidden = {'javascript', 'file', 'data', 'about'};
    if (forbidden.contains(uri.scheme.toLowerCase())) return null;
    return uri;
  }

  /// Build the URL the answer is sent back on.
  static Uri reply(Uri redirect, Map<String, String> params) => redirect.replace(
        queryParameters: {...redirect.queryParameters, ...params},
      );
}
