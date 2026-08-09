import 'package:flutter/material.dart';
import 'package:solfare/core/solana/session/dapp_connect_service.dart';
import 'package:solfare/core/solana/session/dapp_request.dart';
import 'package:solfare/features/wallet/presentation/widgets/tx_preview_body.dart';

/// Approval sheet for a request from another app.
///
/// The identity shown is the origin host, never a name the dapp chose for
/// itself. Everything the dapp says about its own request is decoration; the
/// preview underneath comes from simulating the transaction.
class DappApprovalSheet extends StatelessWidget {
  final DappPrompt prompt;
  final String walletAddress;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const DappApprovalSheet({
    super.key,
    required this.prompt,
    required this.walletAddress,
    required this.onApprove,
    required this.onReject,
  });

  static const _card = Color(0xFF1C1F26);
  static const _danger = Color(0xFFE03131);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 18),
            decoration:
                BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
          Text(
            _title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _origin(),
          const SizedBox(height: 14),
          if (prompt.isSignMessage) _message() else TxPreviewBody(preview: prompt.preview),
          if (prompt.isConnect) _connectTerms(),
          const SizedBox(height: 4),
          _buttons(context),
        ],
      ),
    );
  }

  String get _title => switch (prompt.request) {
        DappConnectRequest() => 'Connect wallet',
        DappSignMessageRequest() => 'Sign message',
        DappSignAndSendRequest() => 'Approve transaction',
        DappSignTransactionRequest() => 'Sign transaction',
        DappDisconnectRequest() => 'Disconnect',
      };

  Widget _origin() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Requested by',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
              const SizedBox(height: 4),
              Text(
                prompt.origin,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Wallet',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
              const SizedBox(height: 2),
              Text(
                _short(walletAddress),
                style: TextStyle(
                    color: Colors.grey[300], fontSize: 12, fontFamily: 'FKGroteskSemiMono'),
              ),
            ],
          ),
        ),
      );

  /// A message is arbitrary text from a stranger. It is shown as a quotation
  /// with its own framing so it cannot be mistaken for the wallet speaking.
  Widget _message() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Message to sign',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
              const SizedBox(height: 8),
              SelectableText(
                prompt.message ?? '',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Signing proves you control this wallet. It never moves funds '
                'on its own, but a signature can be used elsewhere — only sign '
                'text you understand.',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', height: 1.4),
              ),
            ],
          ),
        ),
      );

  Widget _connectTerms() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _term('See your wallet address and balance'),
            _term('Ask you to approve transactions'),
            _term('It cannot move anything without you approving it', good: true),
          ],
        ),
      );

  Widget _term(String text, {bool good = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(good ? Icons.lock_outline : Icons.circle,
                size: good ? 13 : 5,
                color: good ? const Color(0xFF2F9E44) : Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', height: 1.4)),
            ),
          ],
        ),
      );

  Widget _buttons(BuildContext context) {
    final danger = prompt.preview?.hasDanger ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[800]!),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: onReject,
              child: Text('Reject',
                  style: TextStyle(
                      color: Colors.grey[300], fontSize: 13, fontFamily: 'FKGrotesk')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? _danger : Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              onPressed: onApprove,
              child: Text(
                danger ? 'Approve anyway' : 'Approve',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _short(String address) => address.length <= 12
      ? address
      : '${address.substring(0, 6)}…${address.substring(address.length - 6)}';
}
