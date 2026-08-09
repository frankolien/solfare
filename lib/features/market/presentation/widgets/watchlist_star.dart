import 'package:flutter/material.dart';
import 'package:solfare/features/market/data/watchlist_store.dart';

/// The star that puts an asset on the watchlist.
///
/// Reads the store's notifier rather than local state, so every copy of the
/// star for a given mint flips together — the list row, the detail header and
/// the home section are three views of one fact.
class WatchlistStar extends StatelessWidget {
  final String mint;
  final double size;

  const WatchlistStar({super.key, required this.mint, this.size = 20});

  static const _starred = Color(0xFFF4C542);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: WatchlistStore.instance.mints,
      builder: (context, mints, _) {
        final on = mints.contains(mint);
        return GestureDetector(
          onTap: () => WatchlistStore.instance.toggle(mint),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              on ? Icons.star_rounded : Icons.star_outline_rounded,
              color: on ? _starred : Colors.grey[700],
              size: size,
            ),
          ),
        );
      },
    );
  }
}
