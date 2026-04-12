import 'package:flutter/material.dart';

/// Bottom sheet for confirming a SOL transfer with slide-to-approve gesture.
class ConfirmSendSheet extends StatefulWidget {
  final String recipientAddress;
  final String recipientName;
  final double amountInSol;
  final double amountInUsd;
  final VoidCallback onConfirm;

  const ConfirmSendSheet({
    super.key,
    required this.recipientAddress,
    required this.recipientName,
    required this.amountInSol,
    required this.amountInUsd,
    required this.onConfirm,
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
            child: ClipOval(
              child: Image.network(
                "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          Text(
            '${widget.amountInSol} SOL',
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

          // Network fee — estimated, actual fee determined by Solana at transaction time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Network fee', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey),
                  child: Icon(Icons.info_outline, color: Colors.grey[800], size: 14),
                ),
                const Spacer(),
                const Text('0.0000149 SOL', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Slide to approve
          _buildSlideToApprove(),
        ],
      ),
    );
  }

  Widget _buildSlideToApprove() {
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
                  decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(28)),
                ),
                Center(
                  child: Text('Slide to approve', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                ),
                // Draggable circle
                Positioned(
                  left: _slidePosition * maxSlide,
                  top: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _slidePosition += details.delta.dx / maxSlide;
                        _slidePosition = _slidePosition.clamp(0.0, 1.0);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_slidePosition >= _slideThreshold) {
                        widget.onConfirm();
                      } else {
                        setState(() => _slidePosition = 0);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_right, color: Colors.black, size: 28),
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
