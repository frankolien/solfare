import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

/// A token's logo, falling back to its initials.
///
/// Token icons are third-party URLs that go missing often enough that the
/// fallback is the common case, not the edge one.
class MarketTokenIcon extends StatelessWidget {
  final MarketToken token;
  final double size;

  /// Marks the icon when nobody has verified the mint. Trending is where a
  /// wallet meets tokens nobody has checked, and that is the one place the
  /// distinction has to be visible without tapping through.
  final bool warn;

  const MarketTokenIcon({
    super.key,
    required this.token,
    this.size = 36,
    this.warn = false,
  });

  static const _warning = Color(0xFFE8A317);

  @override
  Widget build(BuildContext context) {
    final icon = token.imageUrl.isEmpty
        ? _initials()
        : ClipOval(
            child: Image.network(
              token.imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Decoded at the size actually drawn. Jupiter icons are
              // commonly 512x512 or larger, and each one decoded full-size
              // is ~1 MB of RGBA held in the image cache — a hundred-row
              // list plus the ticker strip pushed it past its budget and
              // scrolling turned into evict-and-re-decode churn.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => _initials(),
            ),
          );

    if (!warn) return icon;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: const BoxDecoration(color: _warning, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: size * 0.26,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    final source = token.symbol.isNotEmpty ? token.symbol : token.name;
    final letters = source.isEmpty
        ? '?'
        : source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letters,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: size * 0.3,
          fontFamily: 'FKGrotesk',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
