import 'package:equatable/equatable.dart';

/// States for HomepageBloc
abstract class HomepageState extends Equatable {
  const HomepageState();

  @override
  List<Object?> get props => [];
}

/// Initial state with selected tab index
class HomepageInitial extends HomepageState {
  final int selectedTabIndex;

  const HomepageInitial({this.selectedTabIndex = 0});

  @override
  List<Object?> get props => [selectedTabIndex];
}
