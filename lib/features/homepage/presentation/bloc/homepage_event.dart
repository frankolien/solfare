import 'package:equatable/equatable.dart';

abstract class HomepageEvent extends Equatable {
  const HomepageEvent();

  @override
  List<Object?> get props => [];
}

/// Event when user selects a navigation tab
class TabSelectedEvent extends HomepageEvent {
  final int index;

  const TabSelectedEvent(this.index);

  @override
  List<Object?> get props => [index];
}
