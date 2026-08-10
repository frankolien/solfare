import 'package:solfare/features/market/domain/entities/market_token.dart';

/// A loaded shelf, plus what it lost on the way.
class MarketFeedResult {
  final List<MarketToken> tokens;
  final int dropped;

  const MarketFeedResult({required this.tokens, this.dropped = 0});

  @override
  String toString() => 'MarketFeedResult(${tokens.length} tokens, $dropped dropped)';
}
