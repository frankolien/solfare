import 'package:bloc/bloc.dart';
import 'package:solfare/features/market/data/datasource/market_datasource.dart';
import 'package:solfare/features/market/presentation/bloc/market_event.dart';
import 'package:solfare/features/market/presentation/bloc/market_state.dart';

class MarketBloc extends Bloc<MarketEvent, MarketState> {
  final MarketDataSource _dataSource;

  MarketBloc({
    MarketDataSource? dataSource,
  })  : _dataSource = dataSource ?? MarketDataSourceImpl(),
        super(const MarketInitial()) {
    on<FetchMarketTokensEvent>(_onFetchMarketTokens);
  }

  Future<void> _onFetchMarketTokens(
    FetchMarketTokensEvent event,
    Emitter<MarketState> emit,
  ) async {
    emit(const MarketLoading());
    try {
      final tokens = await _dataSource.getTopTokens();
      emit(MarketLoaded(tokens));
    } catch (e) {
      emit(MarketError(e.toString()));
    }
  }
}
