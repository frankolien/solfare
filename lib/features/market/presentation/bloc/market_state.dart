import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_sort.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';

enum MarketStatus { initial, loading, ready, failure }

/// One section, in full, sorted.
class MarketState extends Equatable {
  final MarketStatus status;
  final MarketSection section;
  final MarketWindow window;
  final MarketSort sort;
  final bool descending;

  /// Already ordered by [sort] over [window].
  final List<MarketToken> tokens;

  /// The order the feed arrived in, kept so sorting can always start from it.
  final List<MarketToken> unsorted;

  /// Registry mints the API would not stand behind on this load.
  final int dropped;

  final String? error;

  const MarketState({
    this.section = MarketSection.trending,
    this.status = MarketStatus.initial,
    this.window = MarketWindow.h24,
    this.sort = MarketSort.rank,
    this.descending = true,
    this.tokens = const [],
    this.unsorted = const [],
    this.dropped = 0,
    this.error,
  });

  /// True while a load is running over rows that are already on screen.
  bool get isRefreshing => status == MarketStatus.loading && tokens.isNotEmpty;

  MarketState copyWith({
    MarketStatus? status,
    MarketSection? section,
    MarketWindow? window,
    MarketSort? sort,
    bool? descending,
    List<MarketToken>? tokens,
    List<MarketToken>? unsorted,
    int? dropped,
    String? error,
    bool clearError = false,
  }) {
    return MarketState(
      status: status ?? this.status,
      section: section ?? this.section,
      window: window ?? this.window,
      sort: sort ?? this.sort,
      descending: descending ?? this.descending,
      tokens: tokens ?? this.tokens,
      unsorted: unsorted ?? this.unsorted,
      dropped: dropped ?? this.dropped,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props =>
      [status, section, window, sort, descending, tokens, unsorted, dropped, error];
}
