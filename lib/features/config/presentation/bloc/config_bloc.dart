// lib/features/config/presentation/bloc/config_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/machine_config.dart';
import '../../data/repositories/config_repository.dart';

// ── Events ──────────────────────────────────────────────────
abstract class ConfigEvent extends Equatable {
   
 const  ConfigEvent();
  @override List<Object?> get props => [];
}
class ConfigLoadRequested extends ConfigEvent {}
class ConfigOptionAdded extends ConfigEvent {

  final String configType;
  final String value;
  const ConfigOptionAdded(this.configType, this.value);
  @override List<Object?> get props => [configType, value];
}
class ConfigOptionDeleted extends ConfigEvent {
  final String id;
  const ConfigOptionDeleted(this.id);
  @override List<Object?> get props => [id];
}

// ── State ────────────────────────────────────────────────────
class ConfigState extends Equatable {
  final List<String> genres;
  final List<String> brands;
  final List<String> machineTypes;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const ConfigState({
    this.genres = const [],
    this.brands = const [],
    this.machineTypes = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ConfigState copyWith({
    List<String>? genres,
    List<String>? brands,
    List<String>? machineTypes,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) =>
      ConfigState(
        genres: genres ?? this.genres,
        brands: brands ?? this.brands,
        machineTypes: machineTypes ?? this.machineTypes,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        successMessage: successMessage,
      );

  bool get isLoaded =>
      genres.isNotEmpty || brands.isNotEmpty || machineTypes.isNotEmpty;

  @override
  List<Object?> get props =>
      [genres, brands, machineTypes, isLoading, error, successMessage];
}

// ── BLoC ─────────────────────────────────────────────────────
class ConfigBloc extends Bloc<ConfigEvent, ConfigState> {
  ConfigBloc({required ConfigRepository repository})
      : _repo = repository,
        super(const ConfigState()) {
    on<ConfigLoadRequested>(_onLoad);
    on<ConfigOptionAdded>(_onAdded);
    on<ConfigOptionDeleted>(_onDeleted);
  }

  final ConfigRepository _repo;

  Future<void> _onLoad(
    ConfigLoadRequested event,
    Emitter<ConfigState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final opts = await _repo.getAllOptions();
      emit(state.copyWith(
        genres: opts.genres,
        brands: opts.brands,
        machineTypes: opts.machineTypes,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAdded(
    ConfigOptionAdded event,
    Emitter<ConfigState> emit,
  ) async {
    try {
      await _repo.addOption(
        configType: event.configType,
        value: event.value,
      );
      // Reload all
      final opts = await _repo.getAllOptions();
      emit(state.copyWith(
        genres: opts.genres,
        brands: opts.brands,
        machineTypes: opts.machineTypes,
        successMessage: '"${event.value}" added.',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleted(
    ConfigOptionDeleted event,
    Emitter<ConfigState> emit,
  ) async {
    try {
      await _repo.deleteOption(event.id);
      final opts = await _repo.getAllOptions();
      emit(state.copyWith(
        genres: opts.genres,
        brands: opts.brands,
        machineTypes: opts.machineTypes,
        successMessage: 'Option removed.',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
