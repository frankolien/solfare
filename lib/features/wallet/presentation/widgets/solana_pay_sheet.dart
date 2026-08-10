import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/solana/pay/pay_request.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/presentation/widgets/tx_preview_body.dart';

/// Approval sheet for a scanned Solana Pay request.
///
/// Header differs from a normal send in one way that matters: the merchant's
/// own text is shown, but the host it came from is what identifies it. A
/// label saying "Coinbase" proves nothing; the origin does.
class SolanaPaySheet extends StatelessWidget {
  const SolanaPaySheet({super.key});

  static const _card = Color(0xFF1C1F26);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: BlocBuilder<WalletBloc, WalletState>(
        buildWhen: (_, s) => s is PayResolving || s is PayReady || s is PayFailed,
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              if (state is PayFailed)
                _failed(state.message)
              else ...[
                _header(state is PayReady ? state : null),
                const SizedBox(height: 8),
                TxPreviewBody(preview: state is PayReady ? state.preview : null),
                _approve(context, state is PayReady ? state : null),
              ],
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _handle() => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 18),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(PayReady? ready) {
    final request = ready?.request;
    final origin = request is PayTransactionRequest ? request.origin : null;
    final label = ready?.merchant?.label ?? request?.label;
    final amount = request is PayTransferRequest ? request.amount : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            amount != null ? 'Pay $amount' : 'Payment request',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Requested by',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
                const SizedBox(height: 4),
                Text(
                  // The host, when there is one, is the only part of this the
                  // merchant cannot choose freely.
                  origin ?? _shortAddress(request),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.w500),
                ),
                if (label != null && label.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('“$label”',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk')),
                  Text('name supplied by the merchant',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk')),
                ],
                if (request is PayTransferRequest && request.message != null) ...[
                  const SizedBox(height: 6),
                  Text(request.message!,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk')),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  String _shortAddress(PayRequest? request) {
    if (request is! PayTransferRequest) return 'Unknown';
    final a = request.recipient;
    return a.length <= 12 ? a : '${a.substring(0, 4)}…${a.substring(a.length - 4)}';
  }

  Widget _failed(String message) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE03131), size: 28),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk', height: 1.5)),
          ],
        ),
      );

  Widget _approve(BuildContext context, PayReady? ready) {
    final enabled = ready != null;
    final danger = ready?.preview.needsDeliberateApproval ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: !enabled
                ? const Color(0xFF2A2D35)
                : danger
                    ? const Color(0xFFE03131)
                    : Colors.yellow,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 0,
          ),
          onPressed: enabled
              ? () {
                  Navigator.of(context).pop();
                  context.read<WalletBloc>().add(const ExecutePayEvent());
                }
              : null,
          child: Text(
            !enabled
                ? 'Checking…'
                : danger
                    ? 'Pay anyway'
                    : 'Pay',
            style: TextStyle(
              color: enabled ? Colors.black : Colors.grey[600],
              fontSize: 14,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
