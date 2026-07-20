abstract class DeviceManagementEvent {}

class FetchSessionsRequested extends DeviceManagementEvent {}

class LogOutOtherDevicesRequested extends DeviceManagementEvent {}

class TerminateSessionRequested extends DeviceManagementEvent {
  final String sessionId;
  TerminateSessionRequested(this.sessionId);
}