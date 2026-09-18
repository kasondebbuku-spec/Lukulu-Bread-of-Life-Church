import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';

void main() {
  test('Malformed roles cannot restore legacy privileges', () {
    expect(UserAccess.fromData({'role': 'admin', 'roles': 'admin'}).isAdmin, isFalse);
  });
  test('Legacy finance profiles retain access', () {
    expect(UserAccess.fromData({'role': 'finance'}).canManageGiving, isTrue);
  });
  test('Finance and leadership combine without granting administration', () {
    final access = UserAccess.fromData({
      'roles': ['finance', 'elder']
    });
    expect(access.canManageGiving, isTrue);
    expect(access.canManageAttendance, isTrue);
    expect(access.isAdmin, isFalse);
    expect(access.canManageMembers, isFalse);
  });
  test('Hospitality can register directory members but cannot view finances',
      () {
    final access = UserAccess.fromData({
      'roles': ['hospitality']
    });
    expect(access.canManageMembers, isTrue);
    expect(access.canViewGiving, isFalse);
  });
  test('Oversight is read only', () {
    final access = UserAccess.fromData({
      'roles': ['oversight']
    });
    expect(access.canViewGiving, isTrue);
    expect(access.canManageGiving, isFalse);
  });
  test('Roles array overrides legacy permissions, including revocation', () {
    final access = UserAccess.fromData({
      'role': 'admin',
      'roles': ['member']
    });
    expect(access.isAdmin, isFalse);
    expect(access.canViewGiving, isFalse);
  });
}
