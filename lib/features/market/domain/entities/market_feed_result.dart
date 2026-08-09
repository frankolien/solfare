import 'package:solfare/features/market/domain/entities/market_token.dart';

/// A loaded shelf, plus what it lost on the way.
///
/// [dropped] counts registry mints the API would not stand behind — gone,
/// unverified, or no longer tagged as a real-world asset. A shelf that is
/// short for a reason should be able to say so; silently returning fewer rows
/// reads as "this is all there is".
class MarketFeedResult {
  final List<MarketToken> tokens;
  final int dropped;

  const MarketFeedResult({required this.tokens, this.dropped = 0});

  @override
  String toString() => 'MarketFeedResult(${tokens.length} tokens, $dropped dropped)';
}
