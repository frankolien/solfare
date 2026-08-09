import 'package:equatable/equatable.dart';
import 'package:solfare/features/market/domain/entities/market_section.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';

/// The market home: seven sections, each landing on its own.
///
/// Not one status for the screen. The home is six independent sources plus a
/// local list, and treating them as one transaction would make the whole
/// screen as slow and as fragile as the worst of them.
class MarketHomeState extends Equatable {
  final Map<MarketSection, List<MarketToken>> sections;
  final Set<MarketSection> loading;

  /// Sections whose source did not answer. Held per section so one dead feed
  /// is one empty band rather than an empty screen.
  final Set<MarketSection> failed;

  const MarketHomeState({
    this.sections = const {},
    this.loading = const {},
    this.failed = const {},
  });

  List<MarketToken> tokensFor(MarketSection section) => sections[section] ?? const [];

  bool isLoading(MarketSection section) => loading.contains(section);

  bool hasFailed(MarketSection section) => failed.contains(section);

  /// True before anything at all has arrived, which is the only moment a
  /// full-screen skeleton is the right answer.
  bool get isEmpty => sections.values.every((tokens) => tokens.isEmpty);

  /// Everything the home has seen, by mint. Lets the watchlist redraw from
  /// what is already in hand instead of a request per star.
  Map<String, MarketToken> get byMint => {
        for (final tokens in sections.values)
          for (final token in tokens) token.id: token,
      };

  MarketHomeState copyWith({
    Map<MarketSection, List<MarketToken>>? sections,
    Set<MarketSection>? loading,
    Set<MarketSection>? failed,
  }) {
    return MarketHomeState(
      sections: sections ?? this.sections,
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
    );
  }

  @override
  List<Object?> get props => [sections, loading, failed];
}
