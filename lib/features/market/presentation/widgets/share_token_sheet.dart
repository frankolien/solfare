import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';

/// Shares a token as a card.
///
/// Every number on the card comes from what the screen is already showing. A
/// share image travels further than the screen it came from, so it gets
/// nothing the screen does not have.
class ShareTokenSheet extends StatefulWidget {
  final MarketToken token;

  /// Points behind the card's line, taken from the chart already on screen.
  final List<double> sparkline;

  /// Stamped on the card. Passed in rather than read from the clock so the
  /// card and the caller agree on when it was made.
  final DateTime capturedAt;

  /// The token's brand colour, when its logo had one. Null falls back to
  /// green or red for the direction.
  final Color? accent;

  const ShareTokenSheet({
    super.key,
    required this.token,
    required this.capturedAt,
    this.sparkline = const [],
    this.accent,
  });

  static Future<void> show(
    BuildContext context, {
    required MarketToken token,
    List<double> sparkline = const [],
    DateTime? capturedAt,
    Color? accent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareTokenSheet(
        token: token,
        sparkline: sparkline,
        capturedAt: capturedAt ?? DateTime.now().toUtc(),
        accent: accent,
      ),
    );
  }

  @override
  State<ShareTokenSheet> createState() => _ShareTokenSheetState();
}

class _ShareTokenSheetState extends State<ShareTokenSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  MarketToken get token => widget.token;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _capture();
      final text = '${token.displayName} · ${token.symbol}\n${token.id}';
      if (file == null) {
        // The card would not render. The mint is still worth sharing, and is
        // the part somebody receiving this actually needs.
        await SharePlus.instance.share(ShareParams(text: text));
      } else {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
      }
    } catch (e) {
      debugLog('[Share] failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<File?> _capture() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Disposed on every path. A full-resolution raster of this card is
      // roughly 5 MB, and it was retained per share tap — including on the
      // early return below.
      final image = await boundary.toImage(pixelRatio: 3);
      final ByteData? data;
      try {
        data = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (data == null) return null;

      final directory = await getTemporaryDirectory();
      // The symbol is arbitrary API-supplied text, and it was going straight
      // into a path: `../` escapes the temp directory and a `/` just makes
      // the write fail, silently degrading the share to text-only.
      final safeSymbol = token.symbol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final basename = safeSymbol.isEmpty ? 'token' : safeSymbol;
      final file = File('${directory.path}/$basename-solfare.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file;
    } catch (e) {
      debugLog('[Share] could not render the card: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Share token',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          RepaintBoundary(key: _cardKey, child: _card()),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4D03F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: _sharing ? null : _share,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share, color: Colors.black, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      _sharing ? 'Preparing…' : 'Share',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    final change = token.priceChange(MarketWindow.h24);
    final positive = change >= 0;
    // The line takes the brand colour; the percentage keeps green and red,
    // because that one has to mean up and down.
    final lineColor = widget.accent ?? (positive ? MarketRow.up : MarketRow.down);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF15191F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                MarketTokenIcon(token: token, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.symbol.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        token.displayName,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontFamily: 'FKGrotesk',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MarketFormat.price(token.currentPrice),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: widget.sparkline.length < 2
                ? const SizedBox.shrink()
                : CustomPaint(
                    size: const Size(double.infinity, 56),
                    painter: _SparklinePainter(
                      points: widget.sparkline,
                      color: lineColor,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Row(
              children: [
                _stat('Market cap', MarketFormat.compact(token.marketCap)),
                _stat('24h Volume', MarketFormat.compact(token.volume24h)),
                _stat('Liquidity', MarketFormat.compact(token.liquidity)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEFEF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Text(
                  'Solfare',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _stamp(widget.capturedAt),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 10,
                        fontFamily: 'FKGrotesk',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MarketFormat.shortMint(token.id),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 10,
                        fontFamily: 'FKGroteskSemiMono',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk'),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// A price on a card is only true at a moment, so the card says which.
  static String _stamp(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final utc = time.toUtc();
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    return '${utc.day} ${months[utc.month - 1]} ${utc.year}, $hh:$mm UTC';
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var low = points.first;
    var high = points.first;
    for (final value in points) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = high - low;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      // A flat series has no shape to draw, so it sits on the middle line
      // rather than dividing by zero.
      final normalised = span == 0 ? 0.5 : (points[i] - low) / span;
      final y = size.height - (normalised * size.height * 0.8) - size.height * 0.1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}
