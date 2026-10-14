import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/members/screens/add_staff_dialog.dart';
import 'package:church_cms/services/staff_account_service.dart';

class _Calls {
  final logins = <List<String>>[];
  final grants = <List<Object>>[];
  final resets = <String>[];
  bool failGrant = false;

  StaffAccountService service() => StaffAccountService(
        random: Random(1),
        createLogin: (email, password, name) async {
          logins.add([email, password, name]);
          return 'uid-1';
        },
        grantRoles: (uid, roles) async {
          if (failGrant) throw Exception('denied');
          grants.add([uid, roles]);
        },
        sendPasswordReset: (email) async => resets.add(email),
      );
}

void main() {
  group('StaffAccountService', () {
    test('creates the login, grants only the chosen roles, emails a reset link',
        () async {
      final calls = _Calls();
      await calls.service().createStaff(
        name: '  Pastor Banda ',
        email: ' Pastor@Example.com ',
        roles: {UserRole.pastor, UserRole.member},
      );
      expect(calls.logins.single[0], 'pastor@example.com');
      expect(calls.logins.single[2], 'Pastor Banda');
      expect(calls.grants.single, ['uid-1', ['pastor']]);
      expect(calls.resets.single, 'pastor@example.com');
    });

    test('the temporary password is long and varied, and different each time',
        () {
      final service = _Calls().service();
      final a = service.temporaryPassword();
      final b = service.temporaryPassword();
      expect(a.length, 24);
      expect(a, isNot(b));
      expect(a, matches(RegExp(r'[A-Za-z]')));
      expect(a, matches(RegExp(r'\d')));
    });

    test('rejects a missing name, a bad email or no role before creating anything',
        () async {
      final calls = _Calls();
      final service = calls.service();
      await expectLater(
          service.createStaff(name: '', email: 'a@b.co', roles: {UserRole.elder}),
          throwsArgumentError);
      await expectLater(
          service.createStaff(name: 'A', email: 'nope', roles: {UserRole.elder}),
          throwsArgumentError);
      await expectLater(
          service.createStaff(name: 'A', email: 'a@b.co', roles: {UserRole.member}),
          throwsArgumentError);
      expect(calls.logins, isEmpty);
    });

    test('says so when the account exists but its roles were not saved', () async {
      final calls = _Calls()..failGrant = true;
      await expectLater(
          calls.service().createStaff(
              name: 'A', email: 'a@b.co', roles: {UserRole.finance}),
          throwsA(isA<StaffRolesNotGranted>()));
      expect(calls.resets, isEmpty);
    });
  });

  testWidgets('the Add staff dialog creates an account and confirms',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = _Calls();
    await tester.pumpWidget(ProviderScope(
      overrides: [staffAccountServiceProvider.overrideWithValue(calls.service())],
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AddStaffDialog())),
    ));
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'Mary Phiri');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email address'), 'mary@example.com');
    await tester.tap(find.text('Finance Officer'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(calls.grants.single, ['uid-1', ['finance']]);
    expect(find.text('Account created'), findsOneWidget);
    expect(find.textContaining('mary@example.com'), findsOneWidget);
  });

  testWidgets('the dialog explains what is missing instead of failing silently',
      (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(ProviderScope(
      overrides: [staffAccountServiceProvider.overrideWithValue(calls.service())],
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AddStaffDialog())),
    ));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the person\'s name.'), findsOneWidget);
    expect(calls.logins, isEmpty);
  });
}
