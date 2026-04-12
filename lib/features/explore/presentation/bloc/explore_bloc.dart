import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/explore/data/datasource/explore_datasource.dart';
import 'package:solfare/features/explore/domain/entities/crypto_news.dart';
import 'package:solfare/features/explore/domain/entities/dapp_item.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_event.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_state.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  late final ExploreDataSource _dataSource;

  // Cache news so category switches don't re-fetch
  List<CryptoNews> _cachedNews = [];
  List<DappItem> _allDapps = [];

  ExploreBloc({ExploreDataSource? dataSource}) : super(const ExploreInitial()) {
    _dataSource = dataSource ?? ExploreDataSourceImpl();

    on<FetchNewsEvent>(_onFetchNews);
    on<FetchDappsEvent>(_onFetchDapps);
    on<SelectCategoryEvent>(_onSelectCategory);
  }

  Future<void> _onFetchNews(FetchNewsEvent event, Emitter<ExploreState> emit) async {
    emit(const ExploreLoading());
    try {
      _cachedNews = await _dataSource.fetchNews();
      _allDapps = _dataSource.getDapps();

      emit(ExploreLoaded(
        dapps: _allDapps,
        news: _cachedNews,
        selectedCategory: 'Featured',
      ));
    } catch (e) {
      // Still show dApps even if news fails
      _allDapps = _dataSource.getDapps();
      emit(ExploreLoaded(
        dapps: _allDapps,
        news: const [],
        selectedCategory: 'Featured',
      ));
    }
  }

  Future<void> _onFetchDapps(FetchDappsEvent event, Emitter<ExploreState> emit) async {
    final dapps = _dataSource.getDapps(category: event.category);
    emit(ExploreLoaded(
      dapps: dapps,
      news: _cachedNews,
      selectedCategory: event.category ?? 'Featured',
    ));
  }

  void _onSelectCategory(SelectCategoryEvent event, Emitter<ExploreState> emit) {
    final dapps = _dataSource.getDapps(category: event.category);
    emit(ExploreLoaded(
      dapps: dapps,
      news: _cachedNews,
      selectedCategory: event.category,
    ));
  }
}
