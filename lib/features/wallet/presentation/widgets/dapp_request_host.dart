import 'package:flutter/material.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/deeplink/deep_link_bridge.dart';
import 'package:solfare/core/solana/preview/preview_engine.dart';
import 'package:solfare/core/solana/session/dapp_connect_service.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';
import 'package:solfare/core/solana/session/session_store.dart';
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/wallet/presentation/widgets/dapp_approval_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Watches for dapp requests arriving over the deeplink bridge and drives
/// them to an answer.
///
/// Wraps the app's content rather than living on one screen: a request can
/// arrive whenever the app is opened by another one, and it must not depend
/// on which screen happened to be visible.
class DappRequestHost extends StatefulWidget {
  final Widget child;

  const DappRequestHost({super.key, required this.child});

  @override
  State<DappRequestHost> createState() => _DappRequestHostState();
}

class _DappRequestHostState extends State<DappRequestHost> {
  late final DappConnectService _service;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final rpc = SolanaRpcDataSourceImpl();
    _service = DappConnectService(
      sessions: const SessionStore(),
      transactions: TransactionService(rpc),
      preview: PreviewEngine(rpc),
    );
    DeepLinkBridge.dappRequest.addListener(_onRequest);
    // A request can arrive before this mounts, when the app is launched cold
    // by the deeplink rather than merely resumed.
    if (DeepLinkBridge.dappRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
    }
  }

  @override
  void dispose() {
    DeepLinkBridge.dappRequest.removeListener(_onRequest);
    super.dispose();
  }

  Future<void> _onRequest() async {
    final request = DeepLinkBridge.dappRequest.value;
    if (request == null || _busy) return;

    // Claimed immediately: a second request while one is on screen would
    // otherwise stack two approval sheets over each other.
    _busy = true;
    DeepLinkBridge.dappRequest.value = null;

    try {
      final address = await ActiveWallet.address();
      if (address == null) {
        await _reply(await _service.reject(request,
            message: 'No wallet is set up.', code: DappRequestParser.errorUnauthorized));
        return;
      }

      final prompt = await _service.prepare(request, walletAddress: address);

      // Disconnecting is the one request that needs no approval — a dapp
      // giving up access is not a decision to protect the user from.
      if (request is DappDisconnectRequest) {
        await _reply(await _service.approve(prompt, keyPair: await _keyPair()));
        return;
      }

      if (!mounted) return;
      final approved = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            builder: (sheetContext) => DappApprovalSheet(
              prompt: prompt,
              walletAddress: address,
              onApprove: () => Navigator.of(sheetContext).pop(true),
              onReject: () => Navigator.of(sheetContext).pop(false),
            ),
          ) ??
          false;

      await _reply(approved
          ? await _service.approve(prompt, keyPair: await _keyPair())
          : await _service.reject(request, session: prompt.session));
    } on DappRequestRejected catch (e) {
      await _reply(await _service.reject(request, message: e.message, code: e.code));
    } on SessionCryptoException {
      // The payload did not decrypt. The dapp is told the request was
      // invalid and nothing about which part failed.
      await _reply(await _service.reject(request,
          message: 'Could not read that request.',
          code: DappRequestParser.errorInvalidRequest));
    } catch (e) {
      debugLog('[Dapp] request failed: $e');
      await _reply(await _service.reject(request,
          message: 'Something went wrong.', code: DappRequestParser.errorInvalidRequest));
    } finally {
      _busy = false;
    }
  }

  Future<solana.Ed25519HDKeyPair> _keyPair() async {
    final mnemonic = await ActiveWallet.mnemonic();
    if (mnemonic == null) throw const DappRequestRejected('No wallet is set up.');
    return Keyring.keyPairFromMnemonic(mnemonic);
  }

  Future<void> _reply(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // The dapp not being reachable is not a reason to leave the user stuck.
      debugLog('[Dapp] could not return to $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
