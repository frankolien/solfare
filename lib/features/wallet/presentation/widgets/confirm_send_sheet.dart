import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/presentation/widgets/tx_preview_body.dart';

/// Bottom sheet for confirming a SOL transfer with slide-to-approve gesture.
///
/// The sheet opens straight away and fills in the simulated balance changes
/// when they land, so a slow RPC never leaves the user waiting on a spinner.
class ConfirmSendSheet extends StatefulWidget {
  final String recipientAddress;
  final String recipientName;
  final double amountInSol;
  final double amountInUsd;
  final VoidCallback onConfirm;

  /// Ticker of the asset being sent, and its icon. Default to native SOL.
  final String symbol;
  final String? iconUrl;

  const ConfirmSendSheet({
    super.key,
    required this.recipientAddress,
    required this.recipientName,
    required this.amountInSol,
    required this.amountInUsd,
    required this.onConfirm,
    this.symbol = 'SOL',
    this.iconUrl,
  });

  @override
  State<ConfirmSendSheet> createState() => _ConfirmSendSheetState();
}

class _ConfirmSendSheetState extends State<ConfirmSendSheet> {
  double _slidePosition = 0;
  // User must slide past 70% to confirm — prevents accidental sends
  static const double _slideThreshold = 0.7;

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// A token with no metadata has no icon. Falling back to the Solana logo
  /// would put SOL's badge on something that is not SOL, so unknown assets
  /// get a neutral initial instead.
  Widget _assetIcon() {
    final url = widget.iconUrl ?? (widget.symbol == 'SOL'
        ? 'https://assets.coingecko.com/coins/images/4128/large/solana.png'
        : null);

    if (url != null) {
      return Image.network(
        url,
        width: 56,
        height: 56,
        errorBuilder: (_, __, ___) => _initialBadge(),
      );
    }
    return _initialBadge();
  }

  Widget _initialBadge() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A2D35),
        alignment: Alignment.center,
        child: Text(
          widget.symbol.isEmpty ? '?' : widget.symbol.characters.first.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.bold),
        ),
      );

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(50, 16, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                const Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SOL icon
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: _assetIcon()),
          ),
          const SizedBox(height: 12),

          // Amount
          Text(
            '${widget.amountInSol} ${widget.symbol}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${widget.amountInUsd.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGroteskSemiMono'),
          ),
          const SizedBox(height: 40),

          // To row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('To', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk')),
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      _getInitials(widget.recipientName),
                      style: const TextStyle(color: Colors.white, fontSize: 7, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(widget.recipientName, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 20),

          // Balance changes, risk flags and the real fee, straight from the
          // simulation. The fee used to be a hardcoded 0.0000149 SOL.
          BlocBuilder<WalletBloc, WalletState>(
            buildWhen: (_, s) => s is SendPreviewLoading || s is SendPreviewReady,
            builder: (context, state) {
              final preview = state is SendPreviewReady ? state.preview : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TxPreviewBody(preview: preview),
                  const SizedBox(height: 8),
                  _buildSlideToApprove(preview),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlideToApprove(TxPreview? preview) {
    // Nothing is approvable until the simulation answers. A preview that
    // could not run still unlocks the control — the sheet says it could not
    // be checked, and the choice is the user's.
    // A blocked preview is a refusal, so the control stays dead rather than
    // inviting a slide that cannot succeed.
    final ready = preview != null && !preview.blocked;
    final danger = preview?.hasDanger ?? false;
    final fill = danger ? const Color(0xFFE03131) : Colors.yellow;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSlide = constraints.maxWidth - 56;

          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D35),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Yellow fill that grows as user slides
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: 56 + (_slidePosition * maxSlide),
                  height: 56,
                  decoration: BoxDecoration(
                    color: ready ? fill : const Color(0xFF3A3D45),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                Center(
                  child: Text(
                    preview?.blocked == true
                        ? 'Cannot be sent'
                        : !ready
                            ? 'Checking…'
                            : danger
                                ? 'Slide to approve anyway'
                                : 'Slide to approve',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                  ),
                ),
                // Draggable circle
                Positioned(
                  left: _slidePosition * maxSlide,
                  top: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (!ready) return;
                      setState(() {
                        _slidePosition += details.delta.dx / maxSlide;
                        _slidePosition = _slidePosition.clamp(0.0, 1.0);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (!ready) return;
                      if (_slidePosition >= _slideThreshold) {
                        widget.onConfirm();
                      } else {
                        setState(() => _slidePosition = 0);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ready ? fill : const Color(0xFF3A3D45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_right,
                          color: ready ? Colors.black : Colors.grey[600], size: 28),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
