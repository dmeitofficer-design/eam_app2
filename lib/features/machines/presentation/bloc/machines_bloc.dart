// lib/features/machines/presentation/bloc/machines_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/installed_machine.dart';
import '../../data/repositories/machines_repository.dart';

// ── Events
abstract class MachinesEvent extends Equatable {
  const MachinesEvent();
  @override List<Object?> get props => [];
}
class MachinesFetchRequested extends MachinesEvent {
  final String hospitalId;
  const MachinesFetchRequested(this.hospitalId);
  @override List<Object?> get props => [hospitalId];
}
class MachineFetchByIdRequested extends MachinesEvent {
  final String machineId;
  const MachineFetchByIdRequested(this.machineId);
  @override List<Object?> get props => [machineId];
}
class MachineInvoiceUrlRequested extends MachinesEvent {
  final String storagePath;
  const MachineInvoiceUrlRequested(this.storagePath);
  @override List<Object?> get props => [storagePath];
}

// ── States
abstract class MachinesState extends Equatable {
  const MachinesState();
  @override List<Object?> get props => [];
}
class MachinesInitial extends MachinesState {}
class MachinesLoading extends MachinesState {}
class MachinesLoaded extends MachinesState {
  final List<InstalledMachine> machines;
  const MachinesLoaded(this.machines);
  @override List<Object?> get props => [machines];
}
class MachineDetailLoaded extends MachinesState {
  final InstalledMachine machine;
  final String? signedInvoiceUrl;
  const MachineDetailLoaded(this.machine, {this.signedInvoiceUrl});
  @override List<Object?> get props => [machine, signedInvoiceUrl];
}
class MachinesError extends MachinesState {
  final String message;
  const MachinesError(this.message);
  @override List<Object?> get props => [message];
}

// ── BLoC
class MachinesBloc extends Bloc<MachinesEvent, MachinesState> {
  MachinesBloc({required MachinesRepository repository})
      : _repo = repository,
        super(MachinesInitial()) {
    on<MachinesFetchRequested>(_onFetch);
    on<MachineFetchByIdRequested>(_onFetchById);
    on<MachineInvoiceUrlRequested>(_onInvoiceUrl);
  }

  final MachinesRepository _repo;

  Future<void> _onFetch(
    MachinesFetchRequested event,
    Emitter<MachinesState> emit,
  ) async {
    emit(MachinesLoading());
    try {
      final machines = await _repo.getMachinesByHospital(event.hospitalId);
      emit(MachinesLoaded(machines));
    } catch (e) {
      emit(MachinesError(e.toString()));
    }
  }

  Future<void> _onFetchById(
    MachineFetchByIdRequested event,
    Emitter<MachinesState> emit,
  ) async {
    emit(MachinesLoading());
    try {
      final machine = await _repo.getMachineById(event.machineId);
      emit(MachineDetailLoaded(machine));
    } catch (e) {
      emit(MachinesError(e.toString()));
    }
  }

  Future<void> _onInvoiceUrl(
    MachineInvoiceUrlRequested event,
    Emitter<MachinesState> emit,
  ) async {
    if (state is MachineDetailLoaded) {
      final current = (state as MachineDetailLoaded).machine;
      try {
        final url = await _repo.getInvoiceSignedUrl(event.storagePath);
        emit(MachineDetailLoaded(current, signedInvoiceUrl: url));
      } catch (e) {
        emit(MachinesError(e.toString()));
      }
    }
  }
}
