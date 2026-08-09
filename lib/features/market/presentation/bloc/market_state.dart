import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_category.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

enum MarketStatus { initial, loading, ready, failure }

/// One state object rather than a class per phase, so a category that is
/// still loading can keep the previous rows on screen instead of replacing
/// them with a skeleton the user has already read.
class MarketState extends Equatable {
  final MarketStatus status;
  final MarketCategory category;
  final MarketFeed feed;
  final MarketWindow window;
  final MarketSort sort;
  final bool descending;

  /// Already ordered by [sort] over [window].
  final List<MarketToken> tokens;

  /// Registry mints the API would not stand behind on this load.
  final int dropped;

  final String? error;

  const MarketState({
    this.status = MarketStatus.initial,
    this.category = MarketCategory.tokens,
    this.feed = MarketFeed.trending,
    this.window = MarketWindow.h24,
    // Tokens is the opening category, and it is feed-driven, so the opening
    // order is the feed's own ranking rather than a column of ours.
    this.sort = MarketSort.rank,
    this.descending = true,
    this.tokens = const [],
    this.dropped = 0,
    this.error,
  });

  /// True while a load is running over rows that are already on screen.
  bool get isRefreshing => status == MarketStatus.loading && tokens.isNotEmpty;

  MarketState copyWith({
    MarketStatus? status,
    MarketCategory? category,
    MarketFeed? feed,
    MarketWindow? window,
    MarketSort? sort,
    bool? descending,
    List<MarketToken>? tokens,
    int? dropped,
    String? error,
    bool clearError = false,
  }) {
    return MarketState(
      status: status ?? this.status,
      category: category ?? this.category,
      feed: feed ?? this.feed,
      window: window ?? this.window,
      sort: sort ?? this.sort,
      descending: descending ?? this.descending,
      tokens: tokens ?? this.tokens,
      dropped: dropped ?? this.dropped,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [status, category, feed, window, sort, descending, tokens, dropped, error];
}
