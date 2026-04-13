import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solfare/core/util/copied_toast.dart';

/// Cards with light backgrounds where text should be black.
const _lightCards = {
  'card_3.png', 'card_4.png', 'card_5.png', 'card_6.png',
  'card_8.png', 'card_9.png', 'card_10.png',
};

/// The wallet balance card with background image, balance display, and price change.
class BalanceCard extends StatelessWidget {
  final double balanceInSol;
  final bool isLoading;
  final String? walletAddress;
  final double solPriceUsd;
  final double solPriceChange24h;
  final VoidCallback? onMwTap;
  final VoidCallback? onWalletTap;
  final void Function(String action)? onMoreAction;
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
    this.onMoreAction,
    this.walletName = 'Main Wallet',
    this.cardBackground = 'card_1.png',
  });

  void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    showCopiedToast(context);
  }

  bool get _isLightCard => _lightCards.contains(cardBackground);

  PopupMenuItem<String> _popupItem(IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate USD value, fallback to approximate price if API hasn't responded
    final usdValue = solPriceUsd > 0
        ? (balanceInSol * solPriceUsd).toStringAsFixed(2)
        : (balanceInSol * 86.29).toStringAsFixed(2);
    final parts = usdValue.split('.');
    final textColor = _isLightCard ? Colors.black : Colors.white;
    final subtextColor = _isLightCard ? Colors.black54 : Colors.grey[400]!;
    final iconColor = _isLightCard ? Colors.black : Colors.white;

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
                _buildHeader(context, iconColor, textColor, subtextColor),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                _buildBalanceLabel(subtextColor),
                isLoading ? _buildLoader(textColor) : _buildBalanceAmount(parts, textColor),
                _buildPriceChange(subtextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color iconColor, Color textColor, Color subtextColor) {
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
            child: Center(
              child: Text('MW', style: TextStyle(color: textColor, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(walletName, style: TextStyle(color: textColor, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        if (walletAddress != null)
          GestureDetector(
            onTap: () => _copyAddress(context, walletAddress!),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.copy, color: subtextColor, size: 12),
            ),
          ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                IconButton(icon: Icon(Icons.wallet, color: iconColor), onPressed: onWalletTap, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                Positioned(
                  right: 9,
                  top: 10,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: iconColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: const Color(0xFF1C1F26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: onMoreAction,
              itemBuilder: (_) => [
                _popupItem(Icons.qr_code_scanner, 'Scan QR', 'scan_qr'),
                _popupItem(Icons.edit, 'Rename Wallet', 'rename'),
                _popupItem(Icons.brush, 'Edit background', 'edit_bg'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceLabel(Color subtextColor) {
    return Text(
      'BALANCE',
      style: TextStyle(color: subtextColor, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600, letterSpacing: 1.2),
    );
  }

  Widget _buildLoader(Color textColor) {
    return SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: textColor));
  }

  Widget _buildBalanceAmount(List<String> parts, Color textColor) {
    final centsColor = _isLightCard ? Colors.black45 : const Color(0xFFb8bbc1);
    return Text.rich(
      TextSpan(
        text: '\$${parts[0]}.',
        style: TextStyle(color: textColor, fontSize: 32, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: parts[1], style: TextStyle(color: centsColor, fontSize: 32, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPriceChange(Color subtextColor) {
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final dollarChange = balanceInSol * price * (solPriceChange24h / 100);
    final isPositive = dollarChange >= 0;

    return Row(
      children: [
        Text(
          '${isPositive ? '+' : ''}\$${dollarChange.abs().toStringAsFixed(2)}',
          style: TextStyle(color: subtextColor, fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          '${isPositive ? '+' : ''}${solPriceChange24h.toStringAsFixed(2)}%',
          style: TextStyle(color: subtextColor, fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
