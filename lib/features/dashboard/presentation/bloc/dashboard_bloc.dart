// lib/features/dashboard/presentation/bloc/dashboard_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/dashboard_analytics.dart';
import '../../data/repositories/dashboard_repository.dart';

// ── Events
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override List<Object?> get props => [];
}

class DashboardFetchRequested extends DashboardEvent {
  final bool forceRefresh;

  const DashboardFetchRequested({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

// ── States
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardAnalytics analytics;
  const DashboardLoaded(this.analytics);
  @override List<Object?> get props => [analytics];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override List<Object?> get props => [message];
}

// ── BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required DashboardRepository repository})
      : _repo = repository,
        super(DashboardInitial()) {
    on<DashboardFetchRequested>(_onFetch);
  }

  final DashboardRepository _repo;

  Future<void> _onFetch(
    DashboardFetchRequested event,
    Emitter<DashboardState> emit,
  ) async {
    // CACHE CHECK: If data is already present and this isn't a pull-to-refresh,
    // bail out early to serve the cached analytics instantaneously.
    if (!event.forceRefresh && state is DashboardLoaded) {
      return;
    }

    emit(DashboardLoading());
    try {
      final analytics = await _repo.getAnalytics();
      emit(DashboardLoaded(analytics));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}