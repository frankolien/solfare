import 'package:bloc/bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';

/// BLoC for homepage navigation state
/// 
/// Manages which tab is currently selected in the bottom navigation
class HomepageBloc extends Bloc<HomepageEvent, HomepageState> {
  HomepageBloc() : super(const HomepageInitial()) {
    on<TabSelectedEvent>(_onTabSelected);
  }

  /// Handle tab selection
  void _onTabSelected(
    TabSelectedEvent event,
    Emitter<HomepageState> emit,
  ) {
    emit(HomepageInitial(selectedTabIndex: event.index));
  }
}
