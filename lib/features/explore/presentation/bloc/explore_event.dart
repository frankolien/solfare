import 'package:equatable/equatable.dart';

abstract class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

class FetchNewsEvent extends ExploreEvent {
  const FetchNewsEvent();
}

class FetchDappsEvent extends ExploreEvent {
  final String? category;

  const FetchDappsEvent({this.category});

  @override
  List<Object?> get props => [category];
}

class SelectCategoryEvent extends ExploreEvent {
  final String category;

  const SelectCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}
