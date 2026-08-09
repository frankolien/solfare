import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';

/// The strip of movers across the top of the market.
///
/// It re-reads what the home already loaded rather than opening a price
/// stream of its own. A second source feeding a decoration is a second thing
/// to keep in sync, and the moment it drifts it is a decoration that lies.
class MarketTickerStrip extends StatefulWidget {
  final List<MarketToken> tokens;
  final void Function(MarketToken token)? onTap;

  const MarketTickerStrip({super.key, required this.tokens, this.onTap});

  static const height = 40.0;

  @override
  State<MarketTickerStrip> createState() => _MarketTickerStripState();
}

class _MarketTickerStripState extends State<MarketTickerStrip>
    with SingleTickerProviderStateMixin {
  /// Pixels per second. Slow enough to read, fast enough to look alive.
  static const double _speed = 22;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _runKey = GlobalKey();

  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _runWidth = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (!_scroll.hasClients || delta <= 0) return;

    // The content is laid out twice, so scrolling past one run's width and
    // wrapping back to the start is invisible.
    _runWidth = _measureRun();
    if (_runWidth <= 0) return;

    var next = _scroll.offset + _speed * delta;
    if (next >= _runWidth) next -= _runWidth;
    _scroll.jumpTo(next.clamp(0, _scroll.position.maxScrollExtent));
  }

  double _measureRun() {
    if (_runWidth > 0) return _runWidth;
    final box = _runKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tokens.isEmpty) return const SizedBox(height: MarketTickerStrip.height);

    return SizedBox(
      height: MarketTickerStrip.height,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            Row(key: _runKey, children: [for (final t in widget.tokens) _pill(t)]),
            Row(children: [for (final t in widget.tokens) _pill(t)]),
          ],
        ),
      ),
    );
  }

  Widget _pill(MarketToken token) {
    final change = token.priceChange(MarketWindow.h24);
    final positive = change >= 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(token),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF15191F),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MarketTokenIcon(token: token, size: 18),
              const SizedBox(width: 6),
              Text(
                token.symbol.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                positive ? Icons.north_east : Icons.south_east,
                size: 9,
                color: positive ? MarketRow.up : MarketRow.down,
              ),
              const SizedBox(width: 2),
              Text(
                '${change.abs().toStringAsFixed(2)}%',
                style: TextStyle(
                  color: positive ? MarketRow.up : MarketRow.down,
                  fontSize: 11,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
