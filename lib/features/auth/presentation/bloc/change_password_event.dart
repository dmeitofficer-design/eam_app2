// lib/features/auth/presentation/bloc/change_password_event.dart
abstract class ChangePasswordEvent {}

class ChangePasswordSubmitted extends ChangePasswordEvent {
  final String currentPassword;
  final String newPassword;

  ChangePasswordSubmitted({required this.currentPassword, required this.newPassword});
}