// lib/features/engineers/presentation/bloc/engineers_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 1. Core Model Import (Points directly to the comprehensive model)
import '../../../machines/data/models/engineer.dart'; 

// 2. Repository Import (Restored so EngineersRepository is defined)
import '../../data/repositories/engineers_repository.dart';

// ── Events ──────────────────────────────────────────────────

abstract class EngineersEvent extends Equatable {
  const EngineersEvent();
  @override
  List<Object?> get props => [];
}

class EngineersFetchAll extends EngineersEvent {}

class EngineersFetchByMachine extends EngineersEvent {
  final String machineId;
  const EngineersFetchByMachine(this.machineId);
  @override
  List<Object?> get props => [machineId];
}

class EngineersCreateRequested extends EngineersEvent {
  final Engineer engineer;
  const EngineersCreateRequested(this.engineer);
  @override
  List<Object?> get props => [engineer];
}

class EngineersUpdateRequested extends EngineersEvent {
  final Engineer engineer;
  const EngineersUpdateRequested(this.engineer);
  @override
  List<Object?> get props => [engineer];
}

class EngineersStatusUpdateRequested extends EngineersEvent {
  final String engineerId;
  final bool isAvailable; // CHANGED: Now uses database-aligned boolean schema[cite: 5]
  const EngineersStatusUpdateRequested(this.engineerId, this.isAvailable);
  @override
  List<Object?> get props => [engineerId, isAvailable];
}

class EngineersDeleteRequested extends EngineersEvent {
  final String engineerId;
  const EngineersDeleteRequested(this.engineerId);
  @override
  List<Object?> get props => [engineerId];
}

// ── States ───────────────────────────────────────────────────

abstract class EngineersState extends Equatable {
  const EngineersState();
  @override
  List<Object?> get props => [];
}

class EngineersInitial extends EngineersState {}
class EngineersLoading extends EngineersState {}

class EngineersLoaded extends EngineersState {
  final List<Engineer> engineers;
  const EngineersLoaded(this.engineers);
  @override
  List<Object?> get props => [engineers];
}

class EngineersActionSuccess extends EngineersState {
  final String message;
  final List<Engineer> engineers;
  const EngineersActionSuccess(this.message, this.engineers);
  @override
  List<Object?> get props => [message, engineers];
}

class EngineersError extends EngineersState {
  final String message;
  const EngineersError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────

class EngineersBloc extends Bloc<EngineersEvent, EngineersState> {
  EngineersBloc({required EngineersRepository repository})
      : _repo = repository,
        super(EngineersInitial()) {
    on<EngineersFetchAll>(_onFetchAll);
    on<EngineersFetchByMachine>(_onFetchByMachine);
    on<EngineersCreateRequested>(_onCreate);
    on<EngineersUpdateRequested>(_onUpdate);
    on<EngineersStatusUpdateRequested>(_onStatusUpdate);
    on<EngineersDeleteRequested>(_onDelete);
  }

  final EngineersRepository _repo;

  List<Engineer> _currentList = [];

  Future<void> _onFetchAll(
    EngineersFetchAll event,
    Emitter<EngineersState> emit,
  ) async {
    emit(EngineersLoading());
    try {
      _currentList = await _repo.getAllEngineers();
      emit(EngineersLoaded(_currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }

  Future<void> _onFetchByMachine(
    EngineersFetchByMachine event,
    Emitter<EngineersState> emit,
  ) async {
    emit(EngineersLoading());
    try {
      _currentList = await _repo.getEngineersByMachine(event.machineId);
      emit(EngineersLoaded(_currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }

  Future<void> _onCreate(
    EngineersCreateRequested event,
    Emitter<EngineersState> emit,
  ) async {
    try {
      final created = await _repo.createEngineer(event.engineer);
      _currentList = [..._currentList, created];
      emit(EngineersActionSuccess('Engineer added successfully.', _currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    EngineersUpdateRequested event,
    Emitter<EngineersState> emit,
  ) async {
    try {
      final updated = await _repo.updateEngineer(event.engineer);
      if (updated != null) {
        _currentList = _currentList
            .map((e) => e.id == updated.id ? updated : e)
            .toList();
      }
      emit(EngineersActionSuccess('Engineer updated.', _currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }

  Future<void> _onStatusUpdate(
    EngineersStatusUpdateRequested event,
    Emitter<EngineersState> emit,
  ) async {
    try {
      // CHANGED: Passes the boolean parameters safely down to your database repo[cite: 5]
      final updated = await _repo.updateEngineerStatus(
        event.engineerId,
        event.isAvailable, 
      );
      if (updated != null) {
        _currentList = _currentList
            .map((e) => e.id == updated.id ? updated : e)
            .toList();
      }
      emit(EngineersActionSuccess('Status updated.', _currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }

  Future<void> _onDelete(
    EngineersDeleteRequested event,
    Emitter<EngineersState> emit,
  ) async {
    try {
      await _repo.deleteEngineer(event.engineerId);
      _currentList = _currentList
          .where((e) => e.id != event.engineerId)
          .toList();
      emit(EngineersActionSuccess('Engineer removed.', _currentList));
    } catch (e) {
      emit(EngineersError(e.toString()));
    }
  }
}