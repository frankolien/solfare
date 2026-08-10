import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';

/// One section in full: every row, over any window, sorted any way.
///
/// Reached from a section's chevron on the home. The home answers "what is
/// going on"; this answers "show me all of it".
class MarketListScreen extends StatelessWidget {
  final MarketSection section;

  const MarketListScreen({super.key, required this.section});

  static Route<void> route(MarketSection section) => MaterialPageRoute(
        builder: (_) => MarketListScreen(section: section),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MarketBloc(section: section)..add(const FetchMarketTokensEvent()),
      child: _MarketListView(section: section),
    );
  }
}

class _MarketListView extends StatelessWidget {
  final MarketSection section;

  const _MarketListView({required this.section});

  static const _background = Color(0xFF060A0E);
  static const _chipColor = Color(0xFF15191F);
  static const _accent = Color(0xFF7BD64B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: Text(
          section.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<MarketBloc, MarketState>(
          builder: (context, state) {
            return Column(
              children: [
                _windowRow(context, state),
                _columnHeaders(context, state),
                if (state.dropped > 0) _droppedNotice(state.dropped),
                Expanded(child: _body(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _windowRow(BuildContext context, MarketState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          for (final window in MarketWindow.values)
            _chip(
              label: window.label,
              selected: window == state.window,
              onTap: () => context.read<MarketBloc>().add(SelectWindowEvent(window)),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => _openSortSheet(context, state),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _chipColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, color: Colors.grey[400], size: 12),
                  const SizedBox(width: 6),
                  Text(
                    state.sort.label,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 11,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? _chipColor : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[600],
              fontSize: 11,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // The two right-hand columns double as the sort control, so ordering the
  // list is a tap on the thing being ordered rather than a hidden menu.
  Widget _columnHeaders(BuildContext context, MarketState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              const SizedBox(width: 42),
              Expanded(
                flex: 6,
                child: _headerLabel(context, 'Price / Δ%', MarketSort.priceChange, state,
                    alignLeft: true),
              ),
              _headerLabel(context, 'MC / Vol', MarketSort.marketCap, state),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _headerLabel(
    BuildContext context,
    String label,
    MarketSort? sort,
    MarketState state, {
    bool alignLeft = false,
  }) {
    final active = sort != null && state.sort == sort;
    final text = Text(
      label,
      textAlign: alignLeft ? TextAlign.left : TextAlign.right,
      style: TextStyle(
        color: active ? Colors.white : Colors.grey[600],
        fontSize: 10,
        fontFamily: 'FKGrotesk',
        fontWeight: FontWeight.w500,
      ),
    );

    if (sort == null) return text;

    return GestureDetector(
      onTap: () => context.read<MarketBloc>().add(SelectSortEvent(sort)),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(child: text),
          Icon(
            active
                ? (state.descending ? Icons.arrow_drop_down : Icons.arrow_drop_up)
                : Icons.unfold_more,
            color: active ? Colors.white : Colors.grey[700],
            size: active ? 16 : 12,
          ),
        ],
      ),
    );
  }

  Widget _droppedNotice(int dropped) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(
        '$dropped ${dropped == 1 ? 'asset is' : 'assets are'} not being listed right now.',
        style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk'),
      ),
    );
  }

  Widget _body(BuildContext context, MarketState state) {
    if (state.status == MarketStatus.failure && state.tokens.isEmpty) {
      return _message(state.error ?? 'Could not load this list.');
    }
    if (state.tokens.isEmpty && state.status == MarketStatus.ready) {
      return _message(section.isWatchlist
          ? 'Star any asset to add it to your watchlist.'
          : 'Nothing to show here right now.');
    }
    if (state.tokens.isEmpty) return const MarketRowSkeleton();

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _chipColor,
      onRefresh: () async {
        final bloc = context.read<MarketBloc>();
        bloc.add(const FetchMarketTokensEvent(force: true));
        await bloc.stream.firstWhere((s) => s.status != MarketStatus.loading);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: state.tokens.length,
        itemBuilder: (context, index) {
          final token = state.tokens[index];
          return MarketRow(
            token: token,
            window: state.window,
            showStar: true,
            onTap: () => _openDetail(context, token),
          );
        },
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk'),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, MarketToken token) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TokenDetailScreen(token: token)),
    );
  }

  void _openSortSheet(BuildContext context, MarketState state) {
    final bloc = context.read<MarketBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        // Rank only means something where something else did the ranking.
        final options = MarketSort.values
            .where((s) => s != MarketSort.rank || state.section.shelf == null)
            .toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(
                'Sort by',
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk'),
              ),
              const SizedBox(height: 6),
              for (final option in options)
                ListTile(
                  dense: true,
                  title: Text(
                    option.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                    ),
                  ),
                  trailing: option != state.sort
                      ? null
                      : Icon(
                          state.descending ? Icons.arrow_downward : Icons.arrow_upward,
                          color: _accent,
                          size: 16,
                        ),
                  onTap: () {
                    bloc.add(SelectSortEvent(option));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
