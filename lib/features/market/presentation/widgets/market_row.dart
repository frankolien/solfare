import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';
import 'package:solfare/features/market/presentation/widgets/watchlist_star.dart';

/// One asset in a market list: what it is, what it costs, how big it is.
class MarketRow extends StatelessWidget {
  final MarketToken token;
  final MarketWindow window;
  final VoidCallback? onTap;

  /// Shown on the full list, left off the home's preview rows where the
  /// point is to read five things quickly.
  final bool showStar;

  const MarketRow({
    super.key,
    required this.token,
    required this.window,
    this.onTap,
    this.showStar = false,
  });

  static const up = Color(0xFF7BD64B);
  static const down = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final stats = token.statsFor(window);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 9, showStar ? 6 : 20, 9),
        child: Row(
          children: [
            MarketTokenIcon(token: token, size: 32, warn: !token.isVerified),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    token.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          MarketFormat.price(token.currentPrice),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontFamily: 'FKGroteskSemiMono',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        MarketFormat.percent(stats.priceChange),
                        style: TextStyle(
                          color: stats.priceChange >= 0 ? up : down,
                          fontSize: 11,
                          fontFamily: 'FKGroteskSemiMono',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MarketFormat.compact(token.marketCap),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stats.volume == 0 ? '—' : MarketFormat.compact(stats.volume),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'FKGroteskSemiMono',
                  ),
                ),
              ],
            ),
            if (showStar) WatchlistStar(mint: token.id),
          ],
        ),
      ),
    );
  }
}

/// Rows in the shape of the ones about to arrive.
///
/// A spinner says "wait"; this says "here is what is coming", which is the
/// difference between a screen that feels slow and one that feels busy.
class MarketRowSkeleton extends StatelessWidget {
  final int rows;
  final bool shrinkWrap;

  const MarketRowSkeleton({super.key, this.rows = 10, this.shrinkWrap = false});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: rows,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: _bar(80)),
            _bar(50),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
