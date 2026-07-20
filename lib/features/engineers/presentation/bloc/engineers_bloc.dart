// lib/features/engineers/presentation/bloc/engineers_bloc.dart

import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Core Model Import
import '../../../machines/data/models/engineer.dart'; 

// 2. Repository Import
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
  final bool isAvailable;
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

/// Full list successfully loaded
class EngineersLoaded extends EngineersState {
  final List<Engineer> engineers;
  const EngineersLoaded(this.engineers);
  @override
  List<Object?> get props => [engineers];
}

/// Single action succeeded (Create/Update/Delete) — preserves existing list
class EngineersActionSuccess extends EngineersState {
  final String message;
  final List<Engineer> engineers;
  const EngineersActionSuccess(this.message, this.engineers);
  @override
  List<Object?> get props => [message, engineers];
}

/// Single action failed (e.g. Delete failed) — retains existing list so UI stays rendered
class EngineersActionFailure extends EngineersState {
  final String message;
  final List<Engineer> engineers;
  const EngineersActionFailure(this.message, this.engineers);
  @override
  List<Object?> get props => [message, engineers];
}

/// Full load/fetch failed (No data available to display)
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

  // ── Exception & Error Mapper ──────────────────────────────
  String _mapErrorToUserMessage(Object error) {
    // 1. Direct Socket & Timeout Exceptions
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (error is TimeoutException) {
      return 'Connection timed out. Please check your internet speed and retry.';
    }

    // 2. Supabase / Postgrest Exceptions
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('failed to fetch') ||
          msg.contains('network') ||
          msg.contains('clientexception') ||
          msg.contains('socketexception')) {
        return 'Unable to reach Supabase servers. Please check your internet connection.';
      }
      if (msg.contains('foreign key') || msg.contains('constraint')) {
        return 'Cannot modify or delete this engineer as they are assigned to active machines.';
      }
      if (msg.contains('unique') || msg.contains('duplicate')) {
        return 'An engineer with this information already exists.';
      }
      return error.message;
    }

    // 3. String inspection fallback for generic client/HTTP errors
    final raw = error.toString().toLowerCase();

    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('network_error') ||
        raw.contains('failed to fetch') ||
        raw.contains('connection refused')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data.';
    }

    if (raw.contains('timeout')) {
      return 'Server response took too long. Please try again.';
    }

    if (raw.contains('401') || raw.contains('unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }

    return 'An unexpected error occurred while connecting to the database.';
  }

  // ── Event Handlers ─────────────────────────────────────────

  Future<void> _onFetchAll(
    EngineersFetchAll event,
    Emitter<EngineersState> emit,
  ) async {
    emit(EngineersLoading());
    try {
      _currentList = await _repo.getAllEngineers();
      emit(EngineersLoaded(_currentList));
    } catch (e) {
      emit(EngineersError(_mapErrorToUserMessage(e)));
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
      emit(EngineersError(_mapErrorToUserMessage(e)));
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
      emit(EngineersActionFailure(_mapErrorToUserMessage(e), _currentList));
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
      emit(EngineersActionFailure(_mapErrorToUserMessage(e), _currentList));
    }
  }

  Future<void> _onStatusUpdate(
    EngineersStatusUpdateRequested event,
    Emitter<EngineersState> emit,
  ) async {
    try {
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
      emit(EngineersActionFailure(_mapErrorToUserMessage(e), _currentList));
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
      emit(EngineersActionFailure(_mapErrorToUserMessage(e), _currentList));
    }
  }
}