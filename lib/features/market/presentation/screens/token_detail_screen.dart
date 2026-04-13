import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/wallet/presentation/screens/send_sol_screen.dart';

class TokenDetailScreen extends StatefulWidget {
  final MarketToken token;

  const TokenDetailScreen({super.key, required this.token});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  int _selectedTimeframe = 2; // 0=1m, 1=1H, 2=1D, 3=1W, 4=1M
  bool _isLineChart = true;
  final _timeframes = ['1m', '1H', '1D', '1W', '1M'];
  final _timeframeDays = ['0.04', '0.08', '1', '7', '30'];
  String? _mintAddress;
  String? _description;
  List<double> _chartData = [];
  bool _isLoadingChart = false;
  double? _touchedPrice;
  int? _touchedIndex;

  // Static caches shared across all instances — survives screen reopens
  static final Map<String, String> _descriptionCache = {};
  static final Map<String, String> _mintCache = {};
  static final Map<String, List<double>> _chartCache = {};
  static final Map<String, DateTime> _chartCacheTime = {};

  @override
  void initState() {
    super.initState();
    _chartData = widget.token.sparklineData;
    _fetchMintAddress();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    final cacheKey = '${widget.token.id}_${_selectedTimeframe}';
    final cachedTime = _chartCacheTime[cacheKey];

    // Use cache if less than 2 minutes old
    if (_chartCache.containsKey(cacheKey) &&
        cachedTime != null &&
        DateTime.now().difference(cachedTime).inSeconds < 120) {
      setState(() {
        _chartData = _chartCache[cacheKey]!;
        _isLoadingChart = false;
      });
      return;
    }

    setState(() => _isLoadingChart = true);
    try {
      final days = _timeframeDays[_selectedTimeframe];
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/${widget.token.id}/market_chart?vs_currency=usd&days=$days'),
        headers: {'Accept': 'application/json', 'User-Agent': 'Solfare-Wallet/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prices = data['prices'] as List;
        final chartData = prices.map((p) => (p[1] as num).toDouble()).toList();
        _chartCache[cacheKey] = chartData;
        _chartCacheTime[cacheKey] = DateTime.now();
        if (mounted) {
          setState(() {
            _chartData = chartData;
            _isLoadingChart = false;
          });
        }
      } else {
        // On rate limit, try cache even if stale
        if (_chartCache.containsKey(cacheKey)) {
          if (mounted) setState(() { _chartData = _chartCache[cacheKey]!; _isLoadingChart = false; });
        } else {
          if (mounted) setState(() => _isLoadingChart = false);
        }
      }
    } catch (_) {
      if (_chartCache.containsKey(cacheKey)) {
        if (mounted) setState(() { _chartData = _chartCache[cacheKey]!; _isLoadingChart = false; });
      } else {
        if (mounted) setState(() => _isLoadingChart = false);
      }
    }
  }

  Future<void> _fetchMintAddress() async {
    final id = widget.token.id;

    // Use cache if available — descriptions and mints don't change
    if (_descriptionCache.containsKey(id) || _mintCache.containsKey(id)) {
      setState(() {
        _description = _descriptionCache[id];
        _mintAddress = _mintCache[id];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/$id?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final platforms = data['platforms'] as Map<String, dynamic>?;
        final desc = (data['description'] as Map<String, dynamic>?)?['en'] as String?;
        if (mounted) {
          setState(() {
            if (platforms != null && platforms.containsKey('solana')) {
              _mintAddress = platforms['solana'] as String?;
              _mintCache[id] = _mintAddress!;
            }
            if (desc != null && desc.isNotEmpty) {
              _description = desc.replaceAll(RegExp(r'<[^>]*>'), '');
              _descriptionCache[id] = _description!;
            }
          });
        }
      }
    } catch (_) {}
  }

  String _truncateMint(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

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
                    _formatPrice(_touchedPrice ?? token.currentPrice),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_touchedPrice != null)
                    Builder(builder: (context) {
                      final pctChange = ((_touchedPrice! - token.currentPrice) / token.currentPrice * 100);
                      final touchChangeColor = pctChange >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
                      final arrow = pctChange >= 0 ? '↗' : '↘';

                      // Estimate timestamp from index
                      final totalPoints = _chartData.length;
                      final daysMap = {'0.04': 0.04, '0.08': 0.08, '1': 1.0, '7': 7.0, '30': 30.0};
                      final totalDays = daysMap[_timeframeDays[_selectedTimeframe]] ?? 1.0;
                      final now = DateTime.now();
                      final pointTime = now.subtract(Duration(
                        minutes: ((totalDays * 24 * 60) * (1 - (_touchedIndex ?? 0) / totalPoints)).toInt(),
                      ));
                      final hour = pointTime.hour.toString().padLeft(2, '0');
                      final minute = pointTime.minute.toString().padLeft(2, '0');
                      final isToday = pointTime.day == now.day && pointTime.month == now.month;
                      final dateStr = isToday ? 'Today, $hour:$minute' : '${pointTime.day}/${pointTime.month}, $hour:$minute';

                      return Row(
                        children: [
                          Text(arrow, style: TextStyle(color: touchChangeColor, fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '${pctChange.abs().toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: touchChangeColor,
                              fontSize: 13,
                              fontFamily: 'FKGroteskSemiMono',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontFamily: 'FKGrotesk',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      );
                    })
                  else
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

            // Chart with glow
            const SizedBox(height: 16),
            Stack(
              children: [
                // Glow behind chart
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 120,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: chartColor.withValues(alpha: 0.18),
                            blurRadius: 100,
                            spreadRadius:50,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Chart
                SizedBox(
                  height: 250,
                  child: _isLineChart
                      ? _buildChart(chartColor)
                      : _buildTradingViewChart(),
                ),
              ],
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
                      onTap: () {
                        setState(() => _selectedTimeframe = i);
                        _fetchChartData();
                      },
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
                        GestureDetector(
                          onTap: () => setState(() => _isLineChart = true),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _isLineChart ? Colors.grey[800] : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.show_chart, color: _isLineChart ? Colors.white : Colors.grey[600], size: 16),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isLineChart = false),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: !_isLineChart ? Colors.grey[800] : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.candlestick_chart, color: !_isLineChart ? Colors.white : Colors.grey[600], size: 16),
                          ),
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
                mainAxisAlignment: MainAxisAlignment.center,
                
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
                  _buildActionButton(Icons.arrow_downward, 'Deposit', enabled: false),
                  _buildActionButton(Icons.swap_horiz, 'Swap', enabled: false),
                  _buildActionButton(Icons.trending_up, 'Limit', enabled: false),
                  _buildActionButton(Icons.send, 'Send', enabled: token.id == 'solana', onTap: () async {
                    final storage = const FlutterSecureStorage();
                    final address = await storage.read(key: 'wallet_address');
                    if (address != null && mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SendSolScreen(
                            senderAddress: address,
                            balanceInSol: 0,
                            solPriceUsd: token.currentPrice,
                          ),
                        ),
                      );
                    }
                  }),
                ],
              ),
            ),

            // About section
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
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
                    _description ?? '${token.name} is a cryptocurrency token.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'FKGrotesk',
                      height: 1.5,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
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
                                _mintAddress != null ? _truncateMint(_mintAddress!) : '...',
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
    if (_isLoadingChart) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
        ),
      );
    }

    final data = _chartData;
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
      padding: const EdgeInsets.only(right: 30,left: 10),
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
            touchCallback: (event, response) {
              if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                setState(() {
                  _touchedPrice = response.lineBarSpots!.first.y;
                  _touchedIndex = response.lineBarSpots!.first.spotIndex;
                });
              }
              if (event is FlPanEndEvent || event is FlTapUpEvent || event is FlLongPressEnd) {
                setState(() {
                  _touchedPrice = null;
                  _touchedIndex = null;
                });
              }
            },
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
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradingViewChart() {
    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
      </style>
    </head>
    <body>
      <div id="chart" style="width:100%;height:250px;"></div>
      <script src="https://unpkg.com/lightweight-charts@4.1.0/dist/lightweight-charts.standalone.production.js"></script>
      <script>
        const chart = LightweightCharts.createChart(document.getElementById('chart'), {
          width: window.innerWidth,
          height: 250,
          layout: { background: { color: 'transparent' }, textColor: '#666' },
          grid: { vertLines: { color: '#1a1a1a' }, horzLines: { color: '#1a1a1a' } },
          crosshair: { mode: 0 },
          rightPriceScale: { borderColor: '#333' },
          timeScale: { borderColor: '#333', timeVisible: true },
        });

        const candleSeries = chart.addCandlestickSeries({
          upColor: '#4CAF50',
          downColor: '#FF5252',
          borderUpColor: '#4CAF50',
          borderDownColor: '#FF5252',
          wickUpColor: '#4CAF50',
          wickDownColor: '#FF5252',
        });

        // Fetch real candlestick data from Binance
        fetch('https://api.binance.com/api/v3/klines?symbol=${widget.token.symbol.toUpperCase()}USDT&interval=15m&limit=96')
          .then(r => r.json())
          .then(data => {
            const candles = data.map(d => ({
              time: d[0] / 1000,
              open: parseFloat(d[1]),
              high: parseFloat(d[2]),
              low: parseFloat(d[3]),
              close: parseFloat(d[4]),
            }));
            candleSeries.setData(candles);
            chart.timeScale().fitContent();
          })
          .catch(e => console.error(e));

        window.addEventListener('resize', () => chart.applyOptions({ width: window.innerWidth }));
      </script>
    </body>
    </html>
    ''';

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            // Only allow the initial about:blank / data load — block all external navigations
            if (request.url.startsWith('about:') || request.url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ))
        ..loadHtmlString(html);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(controller: controller),
      );
    } catch (_) {
      // Fallback for simulator or unsupported platforms
      return Center(
        child: Text(
          'Candlestick chart requires a real device',
          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
        ),
      );
    }
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

  Widget _buildActionButton(IconData icon, String label, {bool enabled = true, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF23262B),
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
        ),
      ),
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

