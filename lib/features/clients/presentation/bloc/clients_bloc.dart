// lib/features/clients/presentation/bloc/clients_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/hospital_client.dart';
import '../../data/repositories/clients_repository.dart';

// ── Events ──────────────────────────────────────────────────

abstract class ClientsEvent extends Equatable {
  @override List<Object?> get props => [];
  const ClientsEvent();
}

class ClientsFetchRequested extends ClientsEvent {
  final bool forceRefresh;

  const ClientsFetchRequested({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class ClientsSearchChanged extends ClientsEvent {
  final String query;
  const ClientsSearchChanged(this.query);
  @override List<Object?> get props => [query];
}

class ClientsDivisionFilterChanged extends ClientsEvent {
  final DivisionType? division;
  const ClientsDivisionFilterChanged(this.division);
  @override List<Object?> get props => [division];
}

class ClientsFacilityFilterChanged extends ClientsEvent {
  final FacilityType? facilityType;
  const ClientsFacilityFilterChanged(this.facilityType);
  @override List<Object?> get props => [facilityType];
}

class ClientsFilterCleared extends ClientsEvent {}

// ── States ───────────────────────────────────────────────────

class ClientsState extends Equatable {
  final List<HospitalClient> clients;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final DivisionType? divisionFilter;
  final FacilityType? facilityTypeFilter;

  const ClientsState({
    this.clients = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.divisionFilter,
    this.facilityTypeFilter,
  });

  ClientsState copyWith({
    List<HospitalClient>? clients,
    bool? isLoading,
    String? error,
    String? searchQuery,
    DivisionType? Function()? divisionFilter,
    FacilityType? Function()? facilityTypeFilter,
  }) =>
      ClientsState(
        clients: clients ?? this.clients,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
        divisionFilter: divisionFilter != null ? divisionFilter() : this.divisionFilter,
        facilityTypeFilter: facilityTypeFilter != null
            ? facilityTypeFilter()
            : this.facilityTypeFilter,
      );

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      divisionFilter != null ||
      facilityTypeFilter != null;

  @override
  List<Object?> get props => [
        clients,
        isLoading,
        error,
        searchQuery,
        divisionFilter,
        facilityTypeFilter,
      ];
}

// ── BLoC ─────────────────────────────────────────────────────

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  ClientsBloc({required ClientsRepository repository})
      : _repo = repository,
        super(const ClientsState()) {
    on<ClientsFetchRequested>(_onFetch);
    on<ClientsSearchChanged>(_onSearchChanged);
    on<ClientsDivisionFilterChanged>(_onDivisionChanged);
    on<ClientsFacilityFilterChanged>(_onFacilityChanged);
    on<ClientsFilterCleared>(_onFilterCleared);
  }

  final ClientsRepository _repo;

Future<void> _onFetch(
    ClientsFetchRequested event,
    Emitter<ClientsState> emit,
  ) async {
    // CACHE CHECK: If not a forced refresh and cache isn't empty, exit early and keep current data
    if (!event.forceRefresh && state.clients.isNotEmpty) {
      return;
    }

    emit(state.copyWith(isLoading: true));
    await _loadClients(emit);
  }

  Future<void> _onSearchChanged(
    ClientsSearchChanged event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(
      searchQuery: event.query,
      isLoading: true,
      divisionFilter: () => null,
      facilityTypeFilter: () => null,
    ));
    await _loadClients(emit);
  }

  Future<void> _onDivisionChanged(
    ClientsDivisionFilterChanged event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(
      divisionFilter: () => event.division,
      isLoading: true,
      searchQuery: '',
    ));
    await _loadClients(emit);
  }

  Future<void> _onFacilityChanged(
    ClientsFacilityFilterChanged event,
    Emitter<ClientsState> emit,
  ) async {
    emit(state.copyWith(
      facilityTypeFilter: () => event.facilityType,
      isLoading: true,
      searchQuery: '',
    ));
    await _loadClients(emit);
  }

  Future<void> _onFilterCleared(
    ClientsFilterCleared event,
    Emitter<ClientsState> emit,
  ) async {
    emit(const ClientsState(isLoading: true));
    await _loadClients(emit);
  }

  Future<void> _loadClients(Emitter<ClientsState> emit) async {
    try {
      final clients = await _repo.getClients(
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
        division: state.divisionFilter,
        facilityType: state.facilityTypeFilter,
      );
      emit(state.copyWith(clients: clients, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
