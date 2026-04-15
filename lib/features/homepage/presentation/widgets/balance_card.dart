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
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final usdValue = balanceInSol * price;
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
                _AnimatedMoney(
                  value: usdValue,
                  textColor: textColor,
                  centsColor: _isLightCard ? Colors.black45 : const Color(0xFFb8bbc1),
                ),
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

/// Renders a USD amount like `$30.40` and animates smoothly between values.
///
/// Uses a [TweenAnimationBuilder] to interpolate the numeric value over
/// ~450ms. Each character is then rendered through [_RollingDigit], which
/// slides vertically as its digit changes — like an odometer / iOS date
/// picker / Jupiter's balance card.
class _AnimatedMoney extends StatefulWidget {
  const _AnimatedMoney({
    required this.value,
    required this.textColor,
    required this.centsColor,
  });

  final double value;
  final Color textColor;
  final Color centsColor;

  @override
  State<_AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<_AnimatedMoney> {
  // Previous value we animate from. Initialised to the first value we see so
  // the initial render is static (no scroll-on-mount).
  late double _previous = widget.value;

  @override
  void didUpdateWidget(covariant _AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previous, end: widget.value),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = v.toStringAsFixed(2);
        final dotIndex = text.indexOf('.');
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _RollingDigit(char: '\$', color: widget.textColor),
            for (var i = 0; i < text.length; i++)
              _RollingDigit(
                char: text[i],
                color: i > dotIndex ? widget.centsColor : widget.textColor,
              ),
          ],
        );
      },
    );
  }
}

/// A single glyph that slides vertically when its value changes. When the
/// incoming [char] isn't a digit (e.g. `.` or `$`) it renders statically.
class _RollingDigit extends StatelessWidget {
  const _RollingDigit({required this.char, required this.color});

  final String char;
  final Color color;

  static const _style = TextStyle(
    fontSize: 32,
    fontFamily: 'FKGroteskSemiMono',
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    final styled = Text(char, style: _style.copyWith(color: color));

    // Non-digits don't need to animate; keeps the $ and . visually anchored.
    if (char.length != 1 || !RegExp(r'[0-9]').hasMatch(char)) {
      return styled;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // Incoming digits slide up from below, outgoing slide up and out.
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.8),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      // Keying by char forces AnimatedSwitcher to treat each value as a new
      // widget so the transition fires.
      child: Padding(
        key: ValueKey(char),
        padding: EdgeInsets.zero,
        child: styled,
      ),
    );
  }
}
