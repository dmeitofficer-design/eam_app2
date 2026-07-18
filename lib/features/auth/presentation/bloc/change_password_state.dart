// lib/features/auth/presentation/bloc/change_password_state.dart
abstract class ChangePasswordState {}

class ChangePasswordInitial extends ChangePasswordState {}
class ChangePasswordLoading extends ChangePasswordState {}
class ChangePasswordSuccess extends ChangePasswordState {}
class ChangePasswordFailure extends ChangePasswordState {
  final String error;
  ChangePasswordFailure(this.error);
}