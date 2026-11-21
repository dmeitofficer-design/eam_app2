import 'package:eam_platform/features/auth/data/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _as(String role) => UserProfile.fromJson({
      'id': 'u1',
      'role': role,
      'created_at': '2026-01-01T00:00:00Z',
    });

void main() {
  test('accountant = viewer + purchases', () {
    final a = _as('accountant');
    expect(a.role, AppRole.accountant);
    expect(a.canManagePurchases, isTrue);
    expect(a.canSubmit, isFalse);
    expect(a.isAdmin, isFalse);
    expect(a.canSeeMachineDetails, isFalse);
  });

  test('only admins and accountants manage purchases', () {
    expect(_as('user').canManagePurchases, isFalse);
    expect(_as('data_entry').canManagePurchases, isFalse);
    expect(_as('admin').canManagePurchases, isTrue);
    expect(_as('super_admin').canManagePurchases, isTrue);
  });

  test('admins can assign accountant', () {
    expect(_as('admin').assignableRoles, contains(AppRole.accountant));
  });
}
