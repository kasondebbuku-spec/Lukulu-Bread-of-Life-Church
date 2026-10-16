import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/members/screens/account_roles_screen.dart';
import 'package:church_cms/models/role_request.dart';
import 'package:church_cms/screens/auth_screen.dart';
import 'package:church_cms/services/auth_service.dart';
import 'package:church_cms/services/role_request_service.dart';

class _SignUpSpy implements AuthService {
  final signUps = <List<String?>>[];

  @override
  Future<User?> signUp(String email, String password, String name,
      {UserRole? requestedRole}) async {
    signUps.add([email, name, requestedRole?.name]);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoleRequests implements RoleRequestService {
  final approved = <List<Object>>[];
  final declined = <String>[];

  @override
  Future<void> approve(String uid, Set<UserRole> current, UserRole requested) async =>
      approved.add([uid, rolesAfterApproval(current, requested)]);

  @override
  Future<void> decline(String uid) async => declined.add(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('role request rules of thumb', () {
    test('admin can never be requested', () {
      expect(requestableRoles, isNot(contains(UserRole.admin)));
      expect(requestableRoles, isNot(contains(UserRole.member)));
      expect(
          pendingRoleRequest({'requestedRole': 'admin'}, UserAccess.member), isNull);
    });

    test('a pending request is the requested role they do not yet hold', () {
      expect(pendingRoleRequest({'requestedRole': 'finance'}, UserAccess.member),
          UserRole.finance);
      expect(
          pendingRoleRequest({'requestedRole': 'finance'},
              const UserAccess({UserRole.finance})),
          isNull);
      expect(pendingRoleRequest({}, UserAccess.member), isNull);
      expect(pendingRoleRequest({'requestedRole': 5}, UserAccess.member), isNull);
    });

    test('approval adds the role, keeps existing ones and drops plain member', () {
      expect(rolesAfterApproval({UserRole.member}, UserRole.finance), ['finance']);
      expect(rolesAfterApproval({UserRole.elder}, UserRole.finance),
          ['elder', 'finance']);
    });
  });

  testWidgets('sign-up lets a person say they are on the finance committee',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final spy = _SignUpSpy();
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(spy)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
    ));
    await tester.tap(find.text('Need an account? Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('You will join as a Member.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Mary');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'm@x.org');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.tap(find.text('Church member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance Officer').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('The Admin will approve'), findsOneWidget);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(spy.signUps.single, ['m@x.org', 'Mary', 'finance']);
    expect(find.textContaining('request to be Finance Officer'), findsOneWidget);
  });

  testWidgets('the Admin sees waiting requests and approves with one tap',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = _FakeRoleRequests();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roleRequestServiceProvider.overrideWithValue(fake),
        userRoleProvider.overrideWith(
            (ref) => Stream.value(const UserAccess({UserRole.admin}))),
        registeredAccountsProvider.overrideWith((ref) => Stream.value([
              const RegisteredAccount('u1', 'Mary Phiri', 'mary@x.org', UserAccess.member,
                  requestedRole: UserRole.finance),
              const RegisteredAccount('u2', 'John Zulu', 'john@x.org', UserAccess.member),
            ])),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AccountRolesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for your approval (1)'), findsOneWidget);
    expect(find.text('Wants to be Finance Officer'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(fake.approved.single, [
      'u1',
      ['finance']
    ]);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(fake.declined.single, 'u1');
  });

  testWidgets('no approval box when nobody is waiting', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userRoleProvider.overrideWith(
            (ref) => Stream.value(const UserAccess({UserRole.admin}))),
        registeredAccountsProvider.overrideWith((ref) => Stream.value([
              const RegisteredAccount('u2', 'John Zulu', 'john@x.org', UserAccess.member),
            ])),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AccountRolesScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting for your approval'), findsNothing);
  });
}
