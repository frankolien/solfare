import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

/// A token's logo, falling back to its initials.
///
/// Token icons are third-party URLs that go missing often enough that the
/// fallback is the common case, not the edge one.
class MarketTokenIcon extends StatelessWidget {
  final MarketToken token;
  final double size;

  const MarketTokenIcon({super.key, required this.token, this.size = 36});

  @override
  Widget build(BuildContext context) {
    if (token.imageUrl.isEmpty) return _initials();
    return ClipOval(
      child: Image.network(
        token.imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initials(),
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
