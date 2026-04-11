import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

class TokenDetailScreen extends StatefulWidget {
  final MarketToken token;

  const TokenDetailScreen({super.key, required this.token});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  int _selectedTimeframe = 2; // 0=1m, 1=1H, 2=1D, 3=1W, 4=1M
  final _timeframes = ['1m', '1H', '1D', '1W', '1M'];

  String _formatLargeNumber(double value) {
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatPrice(double price) {
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final isPositive = token.priceChangePercentage24h >= 0;
    final changeColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final chartColor = isPositive ? const Color(0xFF7B61FF) : const Color(0xFFFF5252);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.network(
                token.imageUrl,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              token.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price + change
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatPrice(token.currentPrice),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        isPositive ? '↗' : '↘',
                        style: TextStyle(color: changeColor, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${token.priceChangePercentage24h.abs().toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: changeColor,
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

            // Chart
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _buildChart(chartColor),
            ),

            // Timeframe selector
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ...List.generate(_timeframes.length, (i) {
                    final isSelected = _selectedTimeframe == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTimeframe = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.grey[800] : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _timeframes[i],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 11,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // Line/candle toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.show_chart, color: Colors.white, size: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.candlestick_chart, color: Colors.grey[600], size: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats row
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStat('Market cap', _formatLargeNumber(token.marketCap)),
                  const SizedBox(width: 24),
                  _buildStatWithChange(
                    'Volume 24h',
                    _formatLargeNumber(token.volume24h),
                    token.priceChangePercentage24h,
                  ),
                  const SizedBox(width: 24),
                  _buildStat('Liquidity', _formatLargeNumber(token.volume24h * 0.5)),
                ],
              ),
            ),

            // Divider
            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.arrow_downward, 'Deposit'),
                  _buildActionButton(Icons.swap_horiz, 'Swap'),
                  _buildActionButton(Icons.trending_up, 'Limit'),
                  _buildActionButton(Icons.send, 'Send'),
                ],
              ),
            ),

            // About section
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    '${token.name} is a cryptocurrency token on the Solana blockchain ecosystem.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'FKGrotesk',
                      height: 1.5,
                    ),
                  ),

                  // Social links
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSocialChip(Icons.language, 'Homepage'),
                      const SizedBox(width: 8),
                      _buildSocialChip(Icons.close, 'X'),
                      const SizedBox(width: 8),
                      _buildSocialChip(Icons.chat_bubble_outline, 'Discord'),
                    ],
                  ),

                  // Mint address + ticker
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mint address',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontFamily: 'FKGrotesk',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '1111...1111',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'FKGroteskSemiMono',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.copy, color: Colors.grey[500], size: 13),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticker',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontFamily: 'FKGrotesk',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            token.symbol.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'FKGroteskSemiMono',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(Color color) {
    final data = widget.token.sparklineData;
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No chart data',
          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
        ),
      );
    }

    // Sample data points for performance
    final step = data.length > 100 ? (data.length / 100).ceil() : 1;
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i += step) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1C1F26),
              getTooltipItems: (spots) => spots.map((spot) {
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(color: color.withValues(alpha: 0.3), strokeWidth: 1, dashArray: [4, 4]),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontFamily: 'FKGrotesk',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatWithChange(String label, String value, double change) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontFamily: 'FKGrotesk',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
              style: TextStyle(
                color: change >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                fontSize: 10,
                fontFamily: 'FKGroteskSemiMono',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF23262B),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'FKGrotesk',
          ),
        ),
      ],
    );
  }

  Widget _buildSocialChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
