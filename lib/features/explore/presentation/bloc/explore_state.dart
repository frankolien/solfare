import 'package:equatable/equatable.dart';
import 'package:solfare/features/explore/domain/entities/crypto_news.dart';
import 'package:solfare/features/explore/domain/entities/dapp_item.dart';

abstract class ExploreState extends Equatable {
  const ExploreState();

  @override
  List<Object?> get props => [];
}

class ExploreInitial extends ExploreState {
  const ExploreInitial();
}

class ExploreLoading extends ExploreState {
  const ExploreLoading();
}

class ExploreLoaded extends ExploreState {
  final List<DappItem> dapps;
  final List<CryptoNews> news;
  final String selectedCategory;

  const ExploreLoaded({
    required this.dapps,
    required this.news,
    required this.selectedCategory,
  });

  @override
  List<Object?> get props => [dapps, news, selectedCategory];
}

class ExploreError extends ExploreState {
  final String message;

  const ExploreError(this.message);

  @override
  List<Object?> get props => [message];
}
