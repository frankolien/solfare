import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/network/coingecko_client.dart';
import 'package:solfare/core/util/copied_toast.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/add_funds_sheet.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';
import 'package:solfare/features/market/presentation/widgets/share_token_sheet.dart';
import 'package:solfare/features/market/presentation/widgets/watchlist_star.dart';
import 'package:solfare/features/swap/presentation/screens/swap_screen.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
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
  static const _up = Color(0xFF7BD64B);
  static const _down = Color(0xFFFF5252);

  int _selectedTimeframe = 2; // 0=1H, 1=4H, 2=1D, 3=1W, 4=1M
  bool _isLineChart = true;

  // CoinGecko fixes granularity by range: five-minute points up to a day,
  // hourly to ninety days. So these are the shortest windows the chart can
  // draw without the label describing something the data is not.
  final _timeframes = ['1H', '4H', '1D', '1W', '1M'];
  final _timeframeDays = ['0.04', '0.17', '1', '7', '30'];

  /// Anchors the overflow menu under the icon that opened it.
  final GlobalKey _moreKey = GlobalKey();

  String? _homepage;
  String? _twitterHandle;
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
      // Links come from the same response as the description, so the chips
      // cost nothing extra and only appear when they point somewhere.
      final links = data['links'] as Map<String, dynamic>?;
      final homepage = ((links?['homepage'] as List?) ?? const [])
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .firstOrNull;
      final twitter = links?['twitter_screen_name'] as String?;
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
          _homepage = homepage;
          _twitterHandle = (twitter == null || twitter.isEmpty) ? null : twitter;
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

  /// Opens the swap, already pointed at this token.
  ///
  /// Not a second buying surface: the swap screen is the one with the balance
  /// handling, the SOL reserve and the Jupiter execute path already tested on
  /// device. Presetting its output is the whole change.
  Future<void> _openBuy() async {
    final token = widget.token;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SwapScreen(
            initialOutput: SwapToken(
              mint: token.id,
              symbol: token.symbol,
              name: token.displayName,
              decimals: token.decimals,
              logoUrl: token.imageUrl.isEmpty ? null : token.imageUrl,
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    // A swap changes the wallet, so the balances behind this screen are stale.
    final address = await ActiveWallet.address();
    if (address == null || !mounted) return;
    context.read<WalletBloc>()
      ..add(FetchBalanceEvent(address))
      ..add(FetchTokensEvent(address));
  }

  Future<void> _openShare() async {
    await ShareTokenSheet.show(
      context,
      token: widget.token,
      sparkline: _chartData,
    );
  }

  /// Add funds, and sending — the two things that were behind action circles
  /// and still need somewhere to live.
  Future<void> _openMoreMenu() async {
    final box = _moreKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx - 200,
      origin.dy + box.size.height,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );

    final canSend = _isSol || widget.holding != null;
    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF23262B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        _menuItem('funds', Icons.arrow_downward, 'Add funds'),
        if (canSend) _menuItem('send', Icons.north_east, 'Send'),
      ],
    );
    if (choice == null || !mounted) return;

    final address = await ActiveWallet.address();
    if (address == null || !mounted) return;

    if (choice == 'funds') {
      await AddFundsSheet.show(context, walletAddress: address);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendSolScreen(
          senderAddress: address,
          balanceInSol: 0,
          solPriceUsd: widget.token.currentPrice,
          token: widget.holding,
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
    final changeColor = headerIsPositive ? _up : _down;
    final isPositive = token.priceChangePercentage24h >= 0;
    final chartColor = isPositive ? const Color(0xFF7B61FF) : _down;

    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (prev, curr) => curr is SolPriceFetched && _isSol,
      listener: (context, state) {
        if (state is SolPriceFetched) {
          _onLivePriceTick(state.priceUsd, state.priceChange24h);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _appBar(token),
        bottomNavigationBar: _buyBar(),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _priceBlock(displayedPrice, displayedChange, changeColor, headerIsPositive),
              const SizedBox(height: 16),
              _chartBlock(chartColor),
              const SizedBox(height: 12),
              _timeframeRow(),
              const SizedBox(height: 22),
              _statsRow(token),
              const SizedBox(height: 26),
              _aboutBlock(token),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(MarketToken token) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MarketTokenIcon(token: token, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              token.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        // Only for a real mint. There is nothing to star about a listing
        // that arrived without one.
        if (_isMintId) WatchlistStar(mint: widget.token.id, size: 18),
        IconButton(
          icon: const Icon(Icons.ios_share, color: Colors.white, size: 18),
          onPressed: _openShare,
        ),
        IconButton(
          key: _moreKey,
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
          onPressed: _openMoreMenu,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _priceBlock(
    double displayedPrice,
    double displayedChange,
    Color changeColor,
    bool headerIsPositive,
  ) {
    return Padding(
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
          const SizedBox(height: 5),
          if (_touchedPrice != null)
            _touchedChange(displayedPrice)
          else
            Row(
              children: [
                Icon(
                  headerIsPositive ? Icons.north_east : Icons.south_east,
                  color: changeColor,
                  size: 13,
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
    );
  }

  /// What the crosshair is sitting on: how far it is from now, and when.
  Widget _touchedChange(double displayedPrice) {
    final pctChange = (_touchedPrice! - displayedPrice) / displayedPrice * 100;
    final touchColor = pctChange >= 0 ? _up : _down;

    final totalPoints = _chartData.length;
    final totalDays = double.tryParse(_timeframeDays[_selectedTimeframe]) ?? 1;
    final now = DateTime.now();
    final pointTime = now.subtract(Duration(
      minutes: totalPoints == 0
          ? 0
          : ((totalDays * 24 * 60) * (1 - (_touchedIndex ?? 0) / totalPoints)).toInt(),
    ));
    final hour = pointTime.hour.toString().padLeft(2, '0');
    final minute = pointTime.minute.toString().padLeft(2, '0');
    final isToday = pointTime.day == now.day && pointTime.month == now.month;
    final stamp =
        isToday ? 'Today, $hour:$minute' : '${pointTime.day}/${pointTime.month}, $hour:$minute';

    return Row(
      children: [
        Icon(pctChange >= 0 ? Icons.north_east : Icons.south_east, color: touchColor, size: 13),
        const SizedBox(width: 4),
        Text(
          '${pctChange.abs().toStringAsFixed(2)}%',
          style: TextStyle(
            color: touchColor,
            fontSize: 13,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text('•', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(width: 8),
        Text(
          stamp,
          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk'),
        ),
      ],
    );
  }

  Widget _chartBlock(Color chartColor) {
    return Stack(
      children: [
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
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: _isLineChart ? _buildChart(chartColor) : _buildTradingViewChart(),
        ),
      ],
    );
  }

  Widget _timeframeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < _timeframes.length; i++)
            GestureDetector(
              onTap: () {
                setState(() => _selectedTimeframe = i);
                _fetchChartData();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: _selectedTimeframe == i ? const Color(0xFF23262B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _timeframes[i],
                  style: TextStyle(
                    color: _selectedTimeframe == i ? Colors.white : Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF15191F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _chartModeButton(Icons.show_chart, isLine: true),
                _chartModeButton(Icons.candlestick_chart, isLine: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartModeButton(IconData icon, {required bool isLine}) {
    final selected = _isLineChart == isLine;
    return GestureDetector(
      onTap: () => setState(() => _isLineChart = isLine),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2D35) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: selected ? Colors.white : Colors.grey[600], size: 15),
      ),
    );
  }

  Widget _statsRow(MarketToken token) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStat('Market cap', MarketFormat.compact(token.marketCap)),
            _statDivider(),
            _buildStat('Volume 24h', MarketFormat.compact(token.volume24h)),
            _statDivider(),
            _buildStat('Liquidity', MarketFormat.compact(token.liquidity)),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() => const VerticalDivider(color: Colors.white12, width: 1, thickness: 1);

  Widget _aboutBlock(MarketToken token) {
    return Padding(
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _description ?? 'No description has been published for ${token.displayName}.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontFamily: 'FKGrotesk',
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _mintField()),
                const VerticalDivider(color: Colors.white12, width: 24, thickness: 1),
                Expanded(child: _labelled('Ticker', token.symbol.toUpperCase())),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _linkChips(token),
        ],
      ),
    );
  }

  Widget _labelled(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk'),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _mintField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mint address',
          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk'),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _mintAddress == null ? null : _copyMintAddress,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _mintAddress != null ? _truncateMint(_mintAddress!) : '…',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.copy,
                // Greyed out until the address has loaded, so the icon never
                // invites a tap that would copy nothing.
                color: _mintAddress == null ? Colors.grey[800] : Colors.grey[500],
                size: 13,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Only links we actually hold. A chip that opens nothing is worse than a
  /// row of two.
  Widget _linkChips(MarketToken token) {
    final mint = _mintAddress;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_homepage != null) _linkChip(Icons.language, 'Homepage', _homepage!),
        if (_twitterHandle != null)
          _linkChip(Icons.alternate_email, 'X', 'https://x.com/$_twitterHandle'),
        if (mint != null)
          _linkChip(Icons.travel_explore, 'Solscan', 'https://solscan.io/token/$mint'),
      ],
    );
  }

  Widget _linkChip(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF15191F),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One decision, at the bottom, where a thumb is.
  ///
  /// The four action circles this replaces were three ways of reaching
  /// screens that exist elsewhere and one thing the screen is actually for.
  Widget _buyBar() {
    final reason = _buyUnavailable;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null) ...[
              Text(
                reason,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontFamily: 'FKGrotesk',
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      reason == null ? const Color(0xFFF4D03F) : const Color(0xFF23262B),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: reason == null ? _openBuy : null,
                child: Text(
                  'Buy',
                  style: TextStyle(
                    color: reason == null ? Colors.black : Colors.grey[600],
                    fontSize: 14,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'FKGrotesk'),
          ),
          const SizedBox(height: 5),
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

}
