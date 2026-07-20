import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'device_management_event.dart';
import 'device_management_state.dart';

class DeviceManagementBloc extends Bloc<DeviceManagementEvent, DeviceManagementState> {
  final AuthRepository _authRepository;

  DeviceManagementBloc(this._authRepository) : super(DeviceManagementInitial()) {
    on<FetchSessionsRequested>(_onFetchSessions);
    on<LogOutOtherDevicesRequested>(_onLogOutOtherDevices);
    on<TerminateSessionRequested>(_onTerminateSession);
  }

  Future<void> _onFetchSessions(
    FetchSessionsRequested event,
    Emitter<DeviceManagementState> emit,
  ) async {
    emit(DeviceManagementLoading());
    try {
      final sessions = await _authRepository.fetchActiveSessions();
      emit(SessionsLoaded(sessions));
    } catch (e) {
      emit(DeviceManagementFailure(e.toString()));
    }
  }

  Future<void> _onLogOutOtherDevices(
    LogOutOtherDevicesRequested event,
    Emitter<DeviceManagementState> emit,
  ) async {
    emit(DeviceManagementLoading());
    try {
      await _authRepository.logOutOtherDevices();
      emit(SessionActionSuccess("Successfully terminated all other active sessions."));
    } catch (e) {
      emit(DeviceManagementFailure(e.toString()));
    }
  }

  Future<void> _onTerminateSession(
    TerminateSessionRequested event,
    Emitter<DeviceManagementState> emit,
  ) async {
    try {
      await _authRepository.removeSession(event.sessionId);
      // Automatically refresh list after a successful eviction
      final remaining = await _authRepository.fetchActiveSessions();
      emit(SessionsLoaded(remaining));
    } catch (e) {
      emit(DeviceManagementFailure(e.toString()));
    }
  }
}