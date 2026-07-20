abstract class DeviceManagementState {}

class DeviceManagementInitial extends DeviceManagementState {}

class DeviceManagementLoading extends DeviceManagementState {}

class SessionsLoaded extends DeviceManagementState {
  final List<Map<String, dynamic>> sessions;
  SessionsLoaded(this.sessions);
}

class SessionActionSuccess extends DeviceManagementState {
  final String message;
  SessionActionSuccess(this.message);
}

class DeviceManagementFailure extends DeviceManagementState {
  final String error;
  DeviceManagementFailure(this.error);
}
