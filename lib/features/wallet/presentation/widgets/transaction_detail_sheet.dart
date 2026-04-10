import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solfare/features/wallet/domain/entities/transactions.dart';

class TransactionDetailSheet extends StatelessWidget {
  final Transaction tx;
  final String walletAddress;

  const TransactionDetailSheet({
    super.key,
    required this.tx,
    required this.walletAddress,
  });

  bool get _isSent => tx.sender.toLowerCase() == walletAddress.toLowerCase();

  String _truncateAddress(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekday = weekdays[date.weekday - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$weekday, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final amountInSol = tx.amount / 1000000000;
    final feeInSol = tx.transactionFee / 1000000000;
    final sign = _isSent ? '-' : '+';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DATE
                _buildSectionLabel('DATE'),
                const SizedBox(height: 4),
                Text(
                  _formatDate(tx.timestamp),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 18),

                // DETAILS
                _buildSectionLabel('DETAILS'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'MW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSent ? 'Main Wallet' : _truncateAddress(tx.sender),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_forward, color: Colors.grey[500], size: 14),
                    const SizedBox(width: 10),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.grey[400],
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSent ? _truncateAddress(tx.receiver) : 'Main Wallet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // TRANSACTION RESULT
                _buildSectionLabel('TRANSACTION RESULT'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1F26),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.network(
                          "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.currency_bitcoin,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${amountInSol.toStringAsFixed(amountInSol == amountInSol.roundToDouble() ? 0 : 2)} SOL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGroteskSemiMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // NETWORK FEE
                _buildSectionLabel('NETWORK FEE'),
                const SizedBox(height: 4),
                Text(
                  '${feeInSol.toStringAsFixed(7)} SOL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 18),

                // TRANSACTION ID
                _buildSectionLabel('TRANSACTION ID'),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final url = 'https://explorer.solana.com/tx/${tx.signature}?cluster=devnet';
                    try {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (context.mounted) {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied — open in browser'),
                            backgroundColor: Color(0xFF1C1F26),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        _truncateAddress(tx.signature),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'FKGroteskSemiMono',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new,
                        color: Colors.grey[500],
                        size: 13,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 9,
        fontFamily: 'FKGrotesk',
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
