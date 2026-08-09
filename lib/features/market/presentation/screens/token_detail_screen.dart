import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/network/coingecko_client.dart';
import 'package:solfare/core/util/copied_toast.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/buy_sheet.dart';
import 'package:solfare/features/market/presentation/widgets/watchlist_star.dart';
import 'package:solfare/features/swap/presentation/screens/swap_screen.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/presentation/screens/receive_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/send_sol_screen.dart';

class TokenDetailScreen extends StatefulWidget {
  final MarketToken token;

  /// The wallet's holding of this token, when it has one. Sending needs the
  /// mint's decimals and the balance, which a market listing does not carry.
  final SplToken? holding;

  const TokenDetailScreen({super.key, required this.token, this.holding});

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

  // Live values pushed in by WalletBloc when SolPriceFetched arrives — both
  // the 5-min CoinGecko poll and the ~1Hz Binance WS tick land here. Used
  // ONLY for native SOL; other tokens fall back to widget.token
  // values frozen at navigation time.
  double? _liveSolPrice;
  double? _liveSolChange;

  // Live mode appends each WS tick to _chartData ring-buffer style, but only
  // on the short timeframes (1m/1H) where a 1Hz tick is visually meaningful.
  // Longer timeframes would dilute their CoinGecko history with sub-second
  // noise, so we leave their chart alone and only update the header.
  static const _liveChartMaxPoints = 240;

  // Bumped before every CoinGecko fetch; the in-flight call's snapshot is
  // compared on completion so a late response from a previous timeframe
  // can't clobber the now-selected one (and can't erase live appends that
  // landed between dispatch and completion).
  int _chartFetchId = 0;

  // Static caches shared across all instances — CoinGeckoClient handles the
  // HTTP cache on disk; these are in-memory shortcuts for mint/description.
  static final Map<String, String> _descriptionCache = {};
  static final Map<String, String> _mintCache = {};

  @override
  void initState() {
    super.initState();
    _chartData = widget.token.sparklineData;
    _fetchMintAddress();
    _fetchChartData();
    // SOL header should start with a real price even if WalletBloc hasn't
    // activated a wallet yet (so the Binance WS hasn't started). One CoinGecko
    // poll fills the header until the WS comes online; no-op for non-SOL.
    if (_isSol) {
      context.read<WalletBloc>().add(const FetchSolPriceEvent());
    }
  }

  /// Native SOL, however it was reached — the market list now hands over the
  /// wrapped SOL mint where the portfolio card used to hand over a CoinGecko
  /// slug, and both mean the token whose price the wallet already streams.
  bool get _isSol =>
      widget.token.id == 'solana' || widget.token.id == SwapToken.sol.mint;

  /// True when [widget.token.id] is a Solana mint (e.g. portfolio SPL tokens)
  /// rather than a CoinGecko slug like `solana`/`usd-coin`. Used to route the
  /// chart/description requests to CoinGecko's contract endpoints.
  bool get _isMintId {
    final id = widget.token.id;
    if (id.length < 32 || id.length > 44) return false;
    return RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(id);
  }

  String _chartUrl(String days) {
    if (_isMintId) {
      return 'https://api.coingecko.com/api/v3/coins/solana/contract/${widget.token.id}/market_chart?vs_currency=usd&days=$days';
    }
    return 'https://api.coingecko.com/api/v3/coins/${widget.token.id}/market_chart?vs_currency=usd&days=$days';
  }

  Future<void> _fetchChartData() async {
    final fetchId = ++_chartFetchId;
    setState(() => _isLoadingChart = true);
    try {
      final days = _timeframeDays[_selectedTimeframe];
      final body = await CoinGeckoClient.instance.getJson(
        _chartUrl(days),
        ttl: const Duration(minutes: 5),
      );
      final prices = body?['prices'] as List?;
      final chartData = prices == null
          ? <double>[]
          : prices.map((p) => (p[1] as num).toDouble()).toList();
      // Drop the result if another fetch was kicked off after us (timeframe
      // changed) — without this, a slow response can clobber a freshly-
      // selected timeframe's data, or erase live-tick appends that landed
      // while this request was in flight.
      if (!mounted || fetchId != _chartFetchId) return;
      setState(() {
        _chartData = chartData;
        _isLoadingChart = false;
      });
    } catch (_) {
      if (mounted && fetchId == _chartFetchId) {
        setState(() => _isLoadingChart = false);
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

    // When the id is already a Solana mint, we already know it.
    if (_isMintId) {
      _mintAddress = id;
      _mintCache[id] = id;
    }

    try {
      final url = _isMintId
          ? 'https://api.coingecko.com/api/v3/coins/solana/contract/$id'
          : 'https://api.coingecko.com/api/v3/coins/$id?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false';
      // Metadata barely changes — cache it for a day.
      final data = await CoinGeckoClient.instance.getJson(
        url,
        ttl: const Duration(hours: 24),
      );
      if (data == null) return;
      final platforms = data['platforms'] as Map<String, dynamic>?;
      final desc = (data['description'] as Map<String, dynamic>?)?['en'] as String?;
      if (mounted) {
        setState(() {
          if (platforms != null && platforms.containsKey('solana')) {
            _mintAddress = platforms['solana'] as String?;
            if (_mintAddress != null) _mintCache[id] = _mintAddress!;
          }
          if (desc != null && desc.isNotEmpty) {
            _description = desc.replaceAll(RegExp(r'<[^>]*>'), '');
            _descriptionCache[id] = _description!;
          }
        });
      }
    } catch (_) {}
  }

  /// Copies the full mint, not the truncated form on screen — the shortened
  /// version is for reading, and pasting it anywhere would fail.
  void _copyMintAddress() {
    final mint = _mintAddress;
    if (mint == null) return;
    Clipboard.setData(ClipboardData(text: mint));
    showCopiedToast(context);
  }

  /// Buying routes through Jupiter, which needs the mint and its decimals.
  /// A row that arrived without them can be looked at but not bought.
  bool get _canBuy => _buyUnavailable == null;

  /// Why the Buy button is off, in a sentence, or null when it is on.
  ///
  /// A greyed-out control with no explanation is the same dead end the
  /// Deposit, Swap and Limit buttons used to be.
  String? get _buyUnavailable {
    if (NetworkConstants.current != SolanaNetwork.mainnet) {
      return 'Buying needs mainnet. Nothing routes on '
          '${NetworkConstants.current.label}.';
    }
    if (!_isMintId || widget.token.decimals == 0) {
      return 'This listing does not carry a mint to route to.';
    }
    // Listed and priced, but no market maker is standing behind it. Better
    // said here than after the user has typed an amount and waited.
    if (widget.token.liquidity == 0) {
      return 'Nothing is quoting ${widget.token.symbol} right now.';
    }
    return null;
  }

  Future<void> _openBuy() async {
    final address = await ActiveWallet.address();
    if (address == null || !mounted) return;
    final signature = await BuySheet.show(
      context,
      asset: widget.token,
      walletAddress: address,
    );
    if (signature == null || !mounted) return;
    // The purchase changed the wallet, so the balances behind this screen
    // are now stale.
    context.read<WalletBloc>()
      ..add(FetchBalanceEvent(address))
      ..add(FetchTokensEvent(address));
  }

  Future<void> _openReceive() async {
    final address = await ActiveWallet.address();
    if (address == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReceiveScreen(walletAddress: address)),
    );
  }

  String _truncateMint(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

  // Called by BlocListener when WalletBloc emits SolPriceFetched. Updates
  // the header price/change for the SOL detail screen and appends a chart
  // point only on the short timeframes (1m / 1H) where 1Hz ticks are useful.
  //
  // Skipped entirely while the candlestick WebView is visible — its
  // controller is rebuilt on every build(), so a 1Hz setState there would
  // tear down and reload the WebView (refetching Binance klines) every
  // second. The candle view has its own live Binance feed via injected JS,
  // so users on candle view aren't losing realtime — they keep it via the
  // chart's own pipeline.
  void _onLivePriceTick(double priceUsd, double changePct) {
    if (!_isSol) return;
    if (!mounted) return;
    if (!_isLineChart) return;
    setState(() {
      _liveSolPrice = priceUsd;
      _liveSolChange = changePct;
      // Append to chart only when a short timeframe is visible AND the user
      // is not currently touching the chart — appending mid-hover shifts
      // every spot's x-position and the touched dot drifts visibly.
      final shouldAppend = _selectedTimeframe <= 1 && _touchedPrice == null;
      if (shouldAppend) {
        _chartData = [..._chartData, priceUsd];
        if (_chartData.length > _liveChartMaxPoints) {
          _chartData = _chartData.sublist(_chartData.length - _liveChartMaxPoints);
        }
      }
    });
  }

  String _formatPrice(double price) {
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    // Live values feed the HEADER price + % text only. Chart palette
    // (chartColor / glow / crosshair) stays bound to the navigation-time
    // 24h direction so a Binance tick crossing zero doesn't flip the line
    // purple↔red mid-session — that would be a visible design change, not
    // a transparent data refresh.
    final displayedPrice = _liveSolPrice ?? token.currentPrice;
    final displayedChange = _liveSolChange ?? token.priceChangePercentage24h;
    final headerIsPositive = displayedChange >= 0;
    final changeColor = headerIsPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final isPositive = token.priceChangePercentage24h >= 0;
    final chartColor = isPositive ? const Color(0xFF7B61FF) : const Color(0xFFFF5252);

    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (prev, curr) =>
          curr is SolPriceFetched && _isSol,
      listener: (context, state) {
        if (state is SolPriceFetched) {
          _onLivePriceTick(state.priceUsd, state.priceChange24h);
        }
      },
      child: Scaffold(
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
          // Only for a real mint. There is nothing to star about a listing
          // that arrived without one.
          if (_isMintId) WatchlistStar(mint: widget.token.id, size: 22),
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
                    _formatPrice(_touchedPrice ?? displayedPrice),
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
                      final pctChange = ((_touchedPrice! - displayedPrice) / displayedPrice * 100);
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
                        headerIsPositive ? '↗' : '↘',
                        style: TextStyle(color: changeColor, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${displayedChange.abs().toStringAsFixed(2)}%',
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
                  _buildStat('Market cap', MarketFormat.compact(token.marketCap)),
                  const SizedBox(width: 24),
                  _buildStatWithChange(
                    'Volume 24h',
                    MarketFormat.compact(token.volume24h),
                    token.priceChangePercentage24h,
                  ),
                  const SizedBox(width: 24),
                  // Was volume × 0.5, which is not liquidity and was never
                  // anything. The API reports the real figure.
                  _buildStat('Liquidity', MarketFormat.compact(token.liquidity)),
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
                  _buildActionButton(
                    Icons.add,
                    'Buy',
                    // Needs a mint to route to. A holding reached from the
                    // portfolio has one; a CoinGecko slug never did.
                    enabled: _canBuy,
                    onTap: _openBuy,
                  ),
                  _buildActionButton(
                    Icons.swap_horiz,
                    'Swap',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SwapScreen()),
                    ),
                  ),
                  _buildActionButton(
                    Icons.arrow_downward,
                    'Deposit',
                    onTap: _openReceive,
                  ),
                  _buildActionButton(
                    Icons.send,
                    'Send',
                    // Native SOL always; an SPL token only when it is actually
                    // held, since sending needs its decimals and balance.
                    enabled: _isSol || widget.holding != null,
                    onTap: () async {
                      final address = await ActiveWallet.address();
                      if (address != null && mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SendSolScreen(
                              senderAddress: address,
                              balanceInSol: 0,
                              solPriceUsd: token.currentPrice,
                              token: widget.holding,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            if (_buyUnavailable != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  _buyUnavailable!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                  ),
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
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _mintAddress == null ? null : _copyMintAddress,
                            child: Row(
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
                                Icon(
                                  Icons.copy,
                                  // Greyed out until the address has loaded,
                                  // so the icon never invites a tap that
                                  // would copy nothing.
                                  color: _mintAddress == null ? Colors.grey[800] : Colors.grey[500],
                                  size: 13,
                                ),
                              ],
                            ),
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

