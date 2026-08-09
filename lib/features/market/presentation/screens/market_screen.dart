import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';
import 'package:solfare/features/market/presentation/widgets/market_row.dart';
import 'package:solfare/features/market/presentation/widgets/market_search_sheet.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const _background = Color(0xFF060A0E);
  static const _chipColor = Color(0xFF15191F);
  static const _accent = Color(0xFF7BD64B);

  @override
  void initState() {
    super.initState();
    context.read<MarketBloc>().add(const FetchMarketTokensEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: BlocBuilder<MarketBloc, MarketState>(
          builder: (context, state) {
            return Column(
              children: [
                _categoryTabs(state),
                if (state.category.isFeedDriven) _feedChips(state),
                _windowRow(state),
                _columnHeaders(state),
                if (state.dropped > 0) _droppedNotice(state.dropped),
                Expanded(child: _body(state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryTabs(MarketState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          for (final category in MarketCategory.values)
            _categoryTab(category, category == state.category),
          const Spacer(),
          GestureDetector(
            onTap: _openSearch,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Icon(Icons.search, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTab(MarketCategory category, bool selected) {
    return GestureDetector(
      onTap: () => context.read<MarketBloc>().add(SelectCategoryEvent(category)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                category.label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[600],
                  fontSize: 16,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 2,
              width: 26,
              color: selected ? _accent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedChips(MarketState state) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        children: [
          for (final feed in MarketFeed.values)
            _chip(
              label: feed.label,
              selected: feed == state.feed,
              onTap: () => context.read<MarketBloc>().add(SelectFeedEvent(feed)),
              large: true,
            ),
        ],
      ),
    );
  }

  Widget _windowRow(MarketState state) {
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
            onTap: () => _openSortSheet(state),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _chipColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, color: Colors.grey[400], size: 14),
                  const SizedBox(width: 6),
                  Text(
                    state.sort.label,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
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
    bool large = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: large ? 16 : 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (large ? _accent.withValues(alpha: 0.15) : _chipColor)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected && large ? _accent.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? (large ? _accent : Colors.white) : Colors.grey[600],
              fontSize: large ? 13 : 12,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// The two right-hand columns double as the sort control, so ordering the
  /// list is a tap on the thing being ordered rather than a hidden menu.
  Widget _columnHeaders(MarketState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              const SizedBox(width: 50),
              Expanded(flex: 5, child: _headerLabel('Token', null, state)),
              Expanded(flex: 4, child: _headerLabel('Price/Δ%', MarketSort.priceChange, state)),
              Expanded(flex: 4, child: _headerLabel('Vol/Net', MarketSort.volume, state)),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _headerLabel(String label, MarketSort? sort, MarketState state) {
    final active = sort != null && state.sort == sort;
    final text = Text(
      label,
      textAlign: sort == null ? TextAlign.left : TextAlign.right,
      style: TextStyle(
        color: active ? Colors.white : Colors.grey[600],
        fontSize: 11,
        fontFamily: 'FKGrotesk',
        fontWeight: FontWeight.w500,
      ),
    );

    if (sort == null) return text;

    return GestureDetector(
      onTap: () => context.read<MarketBloc>().add(SelectSortEvent(sort)),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
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
        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'FKGrotesk'),
      ),
    );
  }

  Widget _body(MarketState state) {
    if (state.status == MarketStatus.failure && state.tokens.isEmpty) {
      return _message(state.error ?? 'Could not load the market.');
    }
    if (state.tokens.isEmpty && state.status == MarketStatus.ready) {
      return _message('Nothing to show on this shelf right now.');
    }
    if (state.tokens.isEmpty) return const _MarketSkeleton();

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _chipColor,
      onRefresh: () async {
        context.read<MarketBloc>().add(const FetchMarketTokensEvent(force: true));
        await context
            .read<MarketBloc>()
            .stream
            .firstWhere((s) => s.status != MarketStatus.loading);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: state.tokens.length,
        itemBuilder: (context, index) {
          final token = state.tokens[index];
          return MarketRow(
            token: token,
            window: state.window,
            onTap: () => _openDetail(token),
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
          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
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

  void _openSortSheet(MarketState state) {
    final bloc = context.read<MarketBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        // Rank only means something where a feed did the ranking.
        final options = MarketSort.values
            .where((s) => s != MarketSort.rank || state.category.isFeedDriven)
            .toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(
                'Sort by',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                ),
              ),
              const SizedBox(height: 6),
              for (final option in options)
                ListTile(
                  dense: true,
                  title: Text(
                    option.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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

/// Shown while the first page loads. Rows rather than a spinner, so the shape
/// of what is coming is already on screen when it arrives.
class _MarketSkeleton extends StatelessWidget {
  const _MarketSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: _bar(70)),
            Expanded(flex: 4, child: Align(alignment: Alignment.centerRight, child: _bar(54))),
            Expanded(flex: 4, child: Align(alignment: Alignment.centerRight, child: _bar(46))),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
