import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';

/// One asset, seen at a glance.
///
/// Used for the shelves on the home, where the question is "what is here"
/// rather than "how does this compare" — so it shows the logo large and the
/// three numbers that fit, and leaves the rest to the list.
class MarketAssetCard extends StatelessWidget {
  final MarketToken token;
  final MarketWindow window;
  final VoidCallback? onTap;

  const MarketAssetCard({
    super.key,
    required this.token,
    this.window = MarketWindow.h24,
    this.onTap,
  });

  static const width = 168.0;
  static const height = 186.0;
  static const _card = Color(0xFF15191F);

  @override
  Widget build(BuildContext context) {
    final change = token.priceChange(window);
    final positive = change >= 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MarketTokenIcon(token: token, size: 56, warn: !token.isVerified),
            const SizedBox(height: 14),
            Text(
              token.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              MarketFormat.price(token.currentPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontFamily: 'FKGroteskSemiMono',
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  positive ? Icons.north_east : Icons.south_east,
                  size: 12,
                  color: positive ? MarketRow.up : MarketRow.down,
                ),
                const SizedBox(width: 3),
                Text(
                  '${change.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: positive ? MarketRow.up : MarketRow.down,
                    fontSize: 13,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cards in the shape of the ones about to arrive.
class MarketAssetCardSkeleton extends StatelessWidget {
  const MarketAssetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MarketAssetCard.width,
      height: MarketAssetCard.height,
      decoration: BoxDecoration(
        color: const Color(0xFF15191F),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
