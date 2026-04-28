import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:solfare/features/homepage/data/portfolio_history.dart';

enum _Timeframe { day, week, month, all }

extension on _Timeframe {
  String get label => switch (this) {
        _Timeframe.day => '1D',
        _Timeframe.week => '1W',
        _Timeframe.month => '1M',
        _Timeframe.all => 'All',
      };

  Duration? get window => switch (this) {
        _Timeframe.day => const Duration(days: 1),
        _Timeframe.week => const Duration(days: 7),
        _Timeframe.month => const Duration(days: 30),
        _Timeframe.all => null,
      };
}

/// Shows the user's total portfolio USD value over time.
///
/// Data comes from [PortfolioHistory] — local snapshots taken on every
/// balance/price refresh. First launch has nothing to show, so we render a
/// friendly empty state instead of an empty chart.
class PortfolioChart extends StatefulWidget {
  final String address;
  final double currentUsdValue;

  const PortfolioChart({
    super.key,
    required this.address,
    required this.currentUsdValue,
  });

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends State<PortfolioChart> {
  _Timeframe _timeframe = _Timeframe.week;
  List<PortfolioSnapshot> _all = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PortfolioChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.currentUsdValue != widget.currentUsdValue) {
      // Refetch snapshots so the line reflects the newly-recorded point.
      _load();
    }
  }

  Future<void> _load() async {
    final data = await PortfolioHistory.instance.load(widget.address);
    if (!mounted) return;
    setState(() {
      _all = data;
      _loaded = true;
    });
  }

  List<PortfolioSnapshot> get _visible {
    final window = _timeframe.window;
    if (window == null) return _all;
    final cutoff = DateTime.now().subtract(window);
    return _all.where((s) => s.at.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(height: 140);
    }

    final visible = _visible;
    final hasEnoughData = visible.length >= 2;

    final startValue = hasEnoughData ? visible.first.usdValue : widget.currentUsdValue;
    final endValue = hasEnoughData ? visible.last.usdValue : widget.currentUsdValue;
    final delta = endValue - startValue;
    final pctChange = startValue == 0 ? 0.0 : (delta / startValue) * 100;
    final isPositive = delta >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1014),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PORTFOLIO',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (hasEnoughData)
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.north_east : Icons.south_east,
                      size: 12,
                      color: isPositive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF5252),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${pctChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        fontSize: 11,
                        fontFamily: 'FKGroteskSemiMono',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: hasEnoughData ? _buildChart(visible, isPositive) : _buildEmpty(),
          ),
          const SizedBox(height: 12),
          _buildTimeframeTabs(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        _all.isEmpty
            ? 'Your portfolio graph starts here.\nCheck back in an hour.'
            : 'Not enough ${_timeframe.label} data yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontFamily: 'FKGrotesk',
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildChart(List<PortfolioSnapshot> data, bool isPositive) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].usdValue));
    }
    final values = data.map((s) => s.usdValue);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // Small vertical breathing room so the line isn't hugging the edges.
    final pad = (maxV - minV) * 0.1;
    final lineColor =
        isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: minV - pad,
        maxY: maxV + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1C1F26),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            getTooltipItems: (touched) => touched.map((t) {
              return LineTooltipItem(
                '\$${t.y.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.25),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeTabs() {
    return Row(
      children: _Timeframe.values.map((tf) {
        final selected = tf == _timeframe;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _timeframe = tf),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1C1F26) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  tf.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[500],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
