import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';

/// One asset in the market list: what it is, what it costs, how it traded.
class MarketRow extends StatelessWidget {
  final MarketToken token;
  final MarketWindow window;
  final VoidCallback? onTap;

  const MarketRow({
    super.key,
    required this.token,
    required this.window,
    this.onTap,
  });

  static const _up = Color(0xFF7BD64B);
  static const _down = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final stats = token.statsFor(window);
    final changeColor = stats.priceChange >= 0 ? _up : _down;
    final netColor = stats.netVolume >= 0 ? _up : _down;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            MarketTokenIcon(token: token, size: 38),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: _identity()),
            Expanded(
              flex: 4,
              child: _pair(
                MarketFormat.price(token.currentPrice),
                MarketFormat.percent(stats.priceChange),
                changeColor,
              ),
            ),
            Expanded(
              flex: 4,
              child: _pair(
                MarketFormat.compact(stats.volume),
                stats.volume == 0 ? '—' : MarketFormat.compact(stats.netVolume),
                netColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity() {
    final age = MarketFormat.age(token.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                token.symbol.isNotEmpty ? token.symbol : MarketFormat.shortMint(token.id),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (token.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: _up, size: 12),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          age ?? token.name,
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'FKGrotesk'),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// A headline number with its secondary underneath, right-aligned so the
  /// columns line up down the list.
  Widget _pair(String top, String bottom, Color bottomColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          top,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          bottom,
          style: TextStyle(
            color: bottomColor,
            fontSize: 11,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
