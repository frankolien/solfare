import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solfare/core/util/copied_toast.dart';

/// The wallet balance card with background image, balance display, and price change.
class BalanceCard extends StatelessWidget {
  final double balanceInSol;
  final bool isLoading;
  final String? walletAddress;
  final double solPriceUsd;
  final double solPriceChange24h;
  final VoidCallback? onMwTap;
  final VoidCallback? onWalletTap;
  final String walletName;
  final String cardBackground;

  const BalanceCard({
    super.key,
    required this.balanceInSol,
    required this.isLoading,
    this.walletAddress,
    required this.solPriceUsd,
    required this.solPriceChange24h,
    this.onMwTap,
    this.onWalletTap,
    this.walletName = 'Main Wallet',
    this.cardBackground = 'card_1.png',
  });

  void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    showCopiedToast(context);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate USD value, fallback to approximate price if API hasn't responded
    final usdValue = solPriceUsd > 0
        ? (balanceInSol * solPriceUsd).toStringAsFixed(2)
        : (balanceInSol * 86.29).toStringAsFixed(2);
    final parts = usdValue.split('.');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      constraints: const BoxConstraints(minHeight: 190),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          // Card background image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/assets/images/wallet_background/$cardBackground',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]?.withOpacity(0.5)),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                _buildBalanceLabel(),
                isLoading ? _buildLoader() : _buildBalanceAmount(parts),
                _buildPriceChange(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onMwTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('MW', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(walletName, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        if (walletAddress != null)
          GestureDetector(
            onTap: () => _copyAddress(context, walletAddress!),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.copy, color: Colors.grey[400], size: 12),
            ),
          ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                IconButton(icon: const Icon(Icons.wallet, color: Colors.white), onPressed: onWalletTap, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                Positioned(
                  right: 9,
                  top: 10,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
                ),
              ],
            ),
            IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceLabel() {
    return Text(
      'BALANCE',
      style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600, letterSpacing: 1.2),
    );
  }

  Widget _buildLoader() {
    return const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
  }

  Widget _buildBalanceAmount(List<String> parts) {
    return Text.rich(
      TextSpan(
        text: '\$${parts[0]}.',
        style: const TextStyle(color: Colors.white, fontSize: 32, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: parts[1], style: const TextStyle(color: Color(0xFFb8bbc1), fontSize: 32, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPriceChange() {
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final dollarChange = balanceInSol * price * (solPriceChange24h / 100);
    final isPositive = dollarChange >= 0;
    const changeColor = Color(0xFFb8bbc1);

    return Row(
      children: [
        Text(
          '${isPositive ? '+' : ''}\$${dollarChange.abs().toStringAsFixed(2)}',
          style: const TextStyle(color: changeColor, fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          '${isPositive ? '+' : ''}${solPriceChange24h.toStringAsFixed(2)}%',
          style: const TextStyle(color: changeColor, fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
