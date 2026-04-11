import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  int _selectedTab = 0; // 0 = Tokens, 1 = Stocks
  String _sortBy = 'Market cap';

  @override
  void initState() {
    super.initState();
    context.read<MarketBloc>().add(const FetchMarketTokensEvent());
  }

  String _formatMarketCap(double value) {
    if (value >= 1e12) return '\$${(value / 1e12).toStringAsFixed(2)}T';
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatPrice(double price) {
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  List<MarketToken> _sortTokens(List<MarketToken> tokens) {
    final sorted = List<MarketToken>.from(tokens);
    switch (_sortBy) {
      case 'Volume':
        sorted.sort((a, b) => b.volume24h.compareTo(a.volume24h));
        break;
      case 'Gainers':
        sorted.sort((a, b) => b.priceChangePercentage24h.compareTo(a.priceChangePercentage24h));
        break;
      case 'Losers':
        sorted.sort((a, b) => a.priceChangePercentage24h.compareTo(b.priceChangePercentage24h));
        break;
      default: // Market cap
        sorted.sort((a, b) => b.marketCap.compareTo(a.marketCap));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF060A0e),
      body: SafeArea(
        child: Column(
          children: [
            // Header: MW icon + Tokens/Stocks toggle + Search
            _buildHeader(),

            // Content
            Expanded(
              child: BlocBuilder<MarketBloc, MarketState>(
                builder: (context, state) {
                  if (state is MarketLoading) {
                    return _buildShimmer();
                  }
                  if (state is MarketLoaded) {
                    return _buildContent(state.tokens);
                  }
                  if (state is MarketError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk'),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          // MW avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 60),

          // Tokens / Stocks toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildTabButton('Tokens', 0),
                _buildTabButton('Stocks', 1),
              ],
            ),
          ),

          const Spacer(),

          // Search icon
          GestureDetector(
            onTap: _showSearchSheet,
            child: const Icon(Icons.search, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontSize: 12,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<MarketToken> tokens) {
    final trending = tokens.take(3).toList();
    final sorted = _sortTokens(tokens);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Trending header
          const Text(
            'Trending',
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

          // Trending cards (horizontal scroll)
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trending.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _buildTrendingCard(trending[index]),
            ),
          ),

          const SizedBox(height: 24),

          // Tokens header + sort
          Row(
            children: [
              Text(
                _selectedTab == 0 ? 'Tokens' : 'Stocks',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showSortMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortBy,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more, color: Colors.grey[400], size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 19),

          // Token list
          ...sorted.map((token) => _buildTokenRow(token)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTrendingCard(MarketToken token) {
    final isPositive = token.priceChangePercentage24h >= 0;
    final changeColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final arrow = isPositive ? '↗' : '↘';

    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 14),
      decoration: BoxDecoration(
        color: Color(0xFF0e1115),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + name
          Row(
            children: [
              ClipOval(
                child: Image.network(
                  token.imageUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 28,
                    height: 28,
                    color: Colors.grey[800],
                    child: Center(
                      child: Text(
                        token.symbol.substring(0, token.symbol.length >= 2 ? 2 : 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'FKGrotesk'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.symbol.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatPrice(token.currentPrice),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontFamily: 'FKGroteskSemiMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          //const Spacer(),
          SizedBox(
            height: 10,
          ),
          // Price change
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '$arrow ${token.priceChangePercentage24h.abs().toStringAsFixed(2)}%',
              style: TextStyle(
                color: changeColor,
                fontSize: 12,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow(MarketToken token) {
    final isPositive = token.priceChangePercentage24h >= 0;
    final changeColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TokenDetailScreen(token: token)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Row(
        children: [
          // Logo
          ClipOval(
            child: Image.network(
              token.imageUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    token.symbol.substring(0, token.symbol.length >= 2 ? 2 : 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGrotesk'),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + price + change
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatPrice(token.currentPrice),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontFamily: 'FKGroteskSemiMono',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${isPositive ? '+' : ''}${token.priceChangePercentage24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 11,
                        fontFamily: 'FKGroteskSemiMono',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Market cap
          Text(
            _formatMarketCap(token.marketCap),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(width: 60, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              children: List.generate(3, (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ),
          ),
          const SizedBox(height: 30),
          ...List.generate(8, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 120, height: 8, decoration: BoxDecoration(color: Colors.grey[850] ?? Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                  ],
                )),
                Container(width: 50, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showSortMenu() {
    final options = ['Market cap', 'Volume', 'Gainers', 'Losers'];
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(200, 400, 20, 0),
      color: const Color(0xFF1C1F26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: options.map((option) => PopupMenuItem(
        onTap: () => setState(() => _sortBy = option),
        child: Text(
          option,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk'),
        ),
      )).toList(),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlocBuilder<MarketBloc, MarketState>(
        builder: (context, state) {
          final tokens = state is MarketLoaded ? state.tokens : <MarketToken>[];
          return _SearchSheet(tokens: tokens);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search Bottom Sheet
// ─────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final List<MarketToken> tokens;
  const _SearchSheet({required this.tokens});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<MarketToken> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.tokens;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.tokens;
      } else {
        _filtered = widget.tokens
            .where((t) =>
                t.name.toLowerCase().contains(query.toLowerCase()) ||
                t.symbol.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0E1014),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey[500], size: 18),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'FKGrotesk',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search or paste address',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontFamily: 'FKGrotesk',
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: _onSearch,
                      autofocus: true,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      // Paste functionality
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Paste',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Token list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final token = _filtered[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.network(
                          token.imageUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            token.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'FKGrotesk',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            token.symbol.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontFamily: 'FKGrotesk',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
