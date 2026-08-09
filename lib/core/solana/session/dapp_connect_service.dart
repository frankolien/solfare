import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/preview/preview_engine.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';
import 'package:solfare/core/solana/session/session_store.dart';
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/util/app_log.dart';

/// What a dapp is asking for, resolved far enough to show someone.
///
/// Produced before any approval and carrying no authority of its own — the
/// user acts on this, then the service acts on their answer.
class DappPrompt {
  final DappRequest request;

  /// Host of the dapp's origin, or the stored origin for a known session.
  /// The only identity the user is shown.
  final String origin;

  /// Set for anything that would put a transaction on chain.
  final TxPreview? preview;

  /// Set for signMessage — the text as the dapp sent it, shown verbatim and
  /// trusted for nothing.
  final String? message;

  /// The decrypted payload, held so approval does not decrypt twice.
  final Map<String, dynamic>? payload;

  final DappSession? session;

  const DappPrompt({
    required this.request,
    required this.origin,
    this.preview,
    this.message,
    this.payload,
    this.session,
  });

  bool get isConnect => request is DappConnectRequest;
  bool get isSignMessage => request is DappSignMessageRequest;
}

/// Refusals that happen before the user is ever asked.
class DappRequestRejected implements Exception {
  final String message;
  final int code;

  const DappRequestRejected(this.message, {this.code = DappRequestParser.errorInvalidRequest});

  @override
  String toString() => message;
}

/// Runs the dApp Connect protocol: sessions, decryption, and the four
/// operations a dapp can ask for.
///
/// It never decides to approve anything. Every path that produces a
/// signature takes the user's answer as an argument.
class DappConnectService {
  final SessionStore _sessions;
  final TransactionService _tx;
  final PreviewEngine _preview;

  const DappConnectService({
    required SessionStore sessions,
    required TransactionService transactions,
    required PreviewEngine preview,
  })  : _sessions = sessions,
        _tx = transactions,
        _preview = preview;

  /// Work out what is being asked, without acting on it.
  Future<DappPrompt> prepare(DappRequest request, {required String walletAddress}) async {
    if (request is DappConnectRequest) {
      return DappPrompt(request: request, origin: request.origin);
    }

    final session = await _sessions.find(
      request.dappPublicKey,
      walletAddress: walletAddress,
    );
    if (session == null) {
      // Either never connected, expired, or connected to a different wallet.
      // The dapp is told to reconnect and nothing else.
      throw const DappRequestRejected(
        'This app is not connected to this wallet.',
        code: DappRequestParser.errorUnauthorized,
      );
    }

    if (request is DappDisconnectRequest) {
      return DappPrompt(request: request, origin: session.origin, session: session);
    }

    final sealed = request as DappSealedRequest;
    final payload = SessionCrypto.open(
      nonce: sealed.nonce,
      payload: sealed.payload,
      sessionPrivateKey: session.sessionPrivateKey,
      dappPublicKey: session.dappPublicKey,
    );

    if (request is DappSignMessageRequest) {
      final raw = payload['message'];
      if (raw is! String || raw.isEmpty) {
        throw const DappRequestRejected('That request had no message to sign.');
      }
      return DappPrompt(
        request: request,
        origin: session.origin,
        session: session,
        payload: payload,
        message: _decodeMessage(raw),
      );
    }

    final base64Tx = _transactionFrom(payload);
    _assertSafeToSign(base64Tx, walletAddress);

    return DappPrompt(
      request: request,
      origin: session.origin,
      session: session,
      payload: payload,
      preview: await _preview.previewSigned(
        base64Tx: base64Tx,
        ownerAddress: walletAddress,
      ),
    );
  }

  /// The user said yes. Returns the URL the dapp is sent back to.
  Future<Uri> approve(DappPrompt prompt, {required solana.Ed25519HDKeyPair keyPair}) async {
    final request = prompt.request;

    if (request is DappConnectRequest) {
      final keys = SessionCrypto.generateKeyPair();
      final now = DateTime.now();
      final token = SessionCrypto.randomToken();

      final session = DappSession(
        origin: request.origin,
        dappPublicKey: request.dappPublicKey,
        sessionPrivateKey: keys.privateKey,
        walletAddress: keyPair.address,
        sessionToken: token,
        createdAt: now,
        lastUsedAt: now,
      );
      await _sessions.save(session);

      final sealed = SessionCrypto.seal(
        payload: {'public_key': keyPair.address, 'session': token},
        sessionPrivateKey: keys.privateKey,
        dappPublicKey: request.dappPublicKey,
      );

      return DappRequestParser.reply(request.redirectLink, {
        'solfare_encryption_public_key': keys.publicKey,
        'nonce': sealed.nonce,
        'data': sealed.payload,
      });
    }

    if (request is DappDisconnectRequest) {
      await _sessions.revoke(request.dappPublicKey);
      return DappRequestParser.reply(request.redirectLink, {'disconnected': 'true'});
    }

    final session = prompt.session!;
    await _sessions.touch(session.dappPublicKey);

    final Map<String, dynamic> result;
    if (request is DappSignMessageRequest) {
      final signature = await keyPair.sign(utf8.encode(prompt.message!));
      result = {'signature': base58.encode(Uint8List.fromList(signature.bytes))};
    } else {
      final base64Tx = _transactionFrom(prompt.payload!);
      if (request is DappSignAndSendRequest) {
        final outcome = await _tx.signAndSendPayload(base64Tx: base64Tx, signer: keyPair);
        if (!outcome.isConfirmed) {
          return _error(request.redirectLink, session,
              outcome.error ?? 'The transaction did not confirm.');
        }
        result = {'signature': outcome.signature};
      } else {
        // signTransaction hands the signed bytes back without broadcasting;
        // the dapp decides when it lands.
        final signed = await _tx.signPayloadOnly(base64Tx: base64Tx, signer: keyPair);
        // Answer in the encoding the dapp used to ask.
        result = {'transaction': base58.encode(base64Decode(signed))};
      }
    }

    final sealed = SessionCrypto.seal(
      payload: result,
      sessionPrivateKey: session.sessionPrivateKey,
      dappPublicKey: session.dappPublicKey,
    );
    return DappRequestParser.reply(request.redirectLink, {
      'nonce': sealed.nonce,
      'data': sealed.payload,
    });
  }

  /// The user said no, or we refused before asking.
  Future<Uri> reject(
    DappRequest request, {
    DappSession? session,
    String message = 'User rejected the request.',
    int code = DappRequestParser.errorUserRejected,
  }) async {
    // A rejection is encrypted when there is a session to encrypt it with, so
    // an observer cannot tell approval from refusal.
    if (session != null) {
      final sealed = SessionCrypto.seal(
        payload: {'errorCode': code, 'errorMessage': message},
        sessionPrivateKey: session.sessionPrivateKey,
        dappPublicKey: session.dappPublicKey,
      );
      return DappRequestParser.reply(request.redirectLink, {
        'nonce': sealed.nonce,
        'data': sealed.payload,
      });
    }

    return DappRequestParser.reply(request.redirectLink, {
      'errorCode': '$code',
      'errorMessage': message,
    });
  }

  Future<Uri> _error(Uri redirect, DappSession session, String message) async {
    final sealed = SessionCrypto.seal(
      payload: {'errorCode': DappRequestParser.errorInvalidRequest, 'errorMessage': message},
      sessionPrivateKey: session.sessionPrivateKey,
      dappPublicKey: session.dappPublicKey,
    );
    return DappRequestParser.reply(redirect, {'nonce': sealed.nonce, 'data': sealed.payload});
  }

  /// Dapps send the transaction base58-encoded inside the sealed payload.
  String _transactionFrom(Map<String, dynamic> payload) {
    final raw = payload['transaction'];
    if (raw is! String || raw.isEmpty) {
      throw const DappRequestRejected('That request had no transaction in it.');
    }
    try {
      return base64Encode(base58.decode(raw));
    } catch (e) {
      debugLog('[Dapp] transaction payload was not base58: $e');
      throw const DappRequestRejected('That transaction could not be read.');
    }
  }

  String _decodeMessage(String raw) {
    try {
      return utf8.decode(base58.decode(raw));
    } catch (_) {
      // Not every message is text. Showing raw bytes is honest; guessing is not.
      return raw;
    }
  }

  /// Refuse anything that would have us sign for an account that is not ours,
  /// or that needs a signature we cannot give.
  void _assertSafeToSign(String base64Tx, String walletAddress) {
    final encoder.SignedTx tx;
    try {
      tx = encoder.SignedTx.decode(base64Tx);
    } catch (e) {
      debugLog('[Dapp] transaction could not be decoded: $e');
      throw const DappRequestRejected('That transaction could not be read.');
    }

    final keys = tx.compiledMessage.accountKeys;
    if (keys.isEmpty || keys.first.toBase58() != walletAddress) {
      throw const DappRequestRejected(
          'That request asks your wallet to pay for someone else\'s transaction.');
    }
    if (tx.compiledMessage.requiredSignatureCount > 1) {
      throw const DappRequestRejected(
          'That request needs signatures from accounts you do not control.');
    }
  }
}
