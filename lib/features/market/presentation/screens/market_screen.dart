import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_state.dart';
import 'package:solfare/features/market/presentation/screens/market_list_screen.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';
import 'package:solfare/features/market/presentation/widgets/market_asset_card.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';
import 'package:solfare/features/market/presentation/widgets/market_search_sheet.dart';
import 'package:solfare/features/market/presentation/widgets/market_ticker_strip.dart';

/// The market, as a set of sections rather than one long list.
///
/// Arriving here, the question is "what do I follow, what is moving, what
/// does this wallet actually offer" — three questions a single filtered table
/// answers badly. Each section's chevron opens that same source in full.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const _background = Color(0xFF060A0E);

  @override
  void initState() {
    super.initState();
    context.read<MarketHomeBloc>().add(const MarketHomeRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: BlocBuilder<MarketHomeBloc, MarketHomeState>(
          builder: (context, state) {
            return Column(
              children: [
                _header(),
                Expanded(child: _body(state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              'MW',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Market',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openSearch,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(MarketHomeState state) {
    return RefreshIndicator(
      color: MarketRow.up,
      backgroundColor: const Color(0xFF15191F),
      onRefresh: () async {
        final bloc = context.read<MarketHomeBloc>();
        bloc.add(const MarketHomeRequested(force: true));
        await bloc.stream.firstWhere((s) => s.loading.isEmpty);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: MarketTickerStrip(tokens: _tickerTokens(state), onTap: _openDetail),
          ),
          const SizedBox(height: 12),
          for (final section in MarketSection.home) _section(state, section),
          _disclaimer(),
        ],
      ),
    );
  }

  /// What scrolls across the top: the user's own list when they have one,
  /// otherwise the majors. Never a separate fetch — this is what the sections
  /// already hold.
  List<MarketToken> _tickerTokens(MarketHomeState state) {
    final watched = state.tokensFor(MarketSection.watchlist);
    if (watched.isNotEmpty) return watched;
    return [
      ...state.tokensFor(MarketSection.majorCrypto),
      ...state.tokensFor(MarketSection.stocks).take(4),
    ];
  }

  Widget _section(MarketHomeState state, MarketSection section) {
    final tokens = state.tokensFor(section);
    final loading = state.isLoading(section);

    // An empty shelf with a heading over it is worse than no heading. The
    // watchlist is the exception: its empty state is the instruction for how
    // to fill it.
    if (tokens.isEmpty && !loading && !section.isWatchlist) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(section, tokens.isNotEmpty),
        if (section.isWatchlist && tokens.isEmpty)
          _watchlistEmpty()
        else if (tokens.isEmpty)
          _sectionSkeleton(section)
        else if (section.style == MarketSectionStyle.cards)
          _cards(section, tokens)
        else
          _rows(section, tokens),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _sectionHeader(MarketSection section, bool tappable) {
    return GestureDetector(
      onTap: tappable
          ? () => Navigator.of(context).push(MarketListScreen.route(section))
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
        child: Row(
          children: [
            Text(
              section.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tappable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _watchlistEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.star_outline_rounded, color: Colors.grey[400], size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No assets yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Star any asset to add it to your watchlist',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cards(MarketSection section, List<MarketToken> tokens) {
    final shown = tokens.take(section.previewCount).toList();
    return SizedBox(
      height: MarketAssetCard.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => MarketAssetCard(
          token: shown[index],
          onTap: () => _openDetail(shown[index]),
        ),
      ),
    );
  }

  Widget _rows(MarketSection section, List<MarketToken> tokens) {
    final shown = tokens.take(section.previewCount).toList();
    return Column(
      children: [
        for (final token in shown)
          MarketRow(
            token: token,
            window: MarketWindow.h24,
            onTap: () => _openDetail(token),
          ),
      ],
    );
  }

  Widget _sectionSkeleton(MarketSection section) {
    if (section.style == MarketSectionStyle.rows) {
      return const MarketRowSkeleton(rows: 3, shrinkWrap: true);
    }
    return SizedBox(
      height: MarketAssetCard.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => const MarketAssetCardSkeleton(),
      ),
    );
  }

  Widget _disclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Text(
        'Prices come from third-party market data and reflect the past 24 hours. '
        'Tokenised stocks, ETFs and commodities are issued by third parties to '
        'track an underlying asset. Holding one is not ownership of that asset '
        'and carries no shareholder rights. Availability varies by jurisdiction, '
        'and past performance says nothing about what happens next.',
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 10,
          fontFamily: 'FKGrotesk',
          height: 1.6,
        ),
      ),
    );
  }

  void _openDetail(MarketToken token) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TokenDetailScreen(token: token)),
    );
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MarketSearchSheet(onSelected: _openDetail),
    );
  }
}
