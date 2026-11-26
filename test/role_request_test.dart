import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/notifications_provider.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/dashboard/widgets/pending_role_banner.dart';
import 'package:church_cms/features/leaders/widgets/role_request_card.dart';
import 'package:church_cms/features/members/screens/account_roles_screen.dart';
import 'package:church_cms/models/ministry_position.dart';
import 'package:church_cms/models/role_request.dart';
import 'package:church_cms/screens/auth_screen.dart';
import 'package:church_cms/services/auth_service.dart';
import 'package:church_cms/services/role_request_service.dart';

class _SignUpSpy implements AuthService {
  final signUps = <List<Object?>>[];
  final signIns = <String>[];

  @override
  Future<User?> signUp(String email, String password, String name,
      {Set<UserRole> requestedRoles = const {},
      MinistryPosition? requestedPosition,
      String? phone}) async {
    signUps.add([email, name, requestedRoles.map((r) => r.name).toSet()]);
    return null;
  }

  @override
  Future<User?> signIn(String email, String password) async {
    signIns.add(email);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRoleRequests implements RoleRequestService {
  final approved = <String>[];
  final declined = <String>[];
  final asked = <Set<UserRole>>[];
  bool failing = false;

  @override
  Future<void> ask(String uid, Set<UserRole> roles) async {
    if (failing) throw StateError('offline');
    asked.add({...roles});
  }

  @override
  Future<void> approve(String uid, UserRole requested) async =>
      approved.add('$uid:${requested.name}');

  @override
  Future<void> decline(String uid, UserRole requested) async =>
      declined.add('$uid:${requested.name}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _tall(WidgetTester tester, [double width = 900]) {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('role request rules of thumb', () {
    test('admin can never be requested', () {
      expect(requestableRoles, isNot(contains(UserRole.admin)));
      expect(requestableRoles, isNot(contains(UserRole.member)));
      expect(pendingRoleRequests({'requestedRoles': ['admin', 'member']}, UserAccess.member),
          isEmpty);
      expect(pendingRoleRequests({'requestedRole': 'admin'}, UserAccess.member), isEmpty);
    });

    test('several roles can be waiting at once, in a fixed order', () {
      expect(
          pendingRoleRequests(
              {'requestedRoles': ['secretariat', 'elder', 'finance', 'elder']},
              UserAccess.member),
          [UserRole.elder, UserRole.finance, UserRole.secretariat]);
    });

    test('a request made before several were allowed still counts', () {
      expect(pendingRoleRequests({'requestedRole': 'finance'}, UserAccess.member),
          [UserRole.finance]);
      expect(
          pendingRoleRequests(
              {'requestedRole': 'finance', 'requestedRoles': ['elder', 'finance']},
              UserAccess.member),
          [UserRole.elder, UserRole.finance]);
    });

    test('a role already held is no longer waiting', () {
      expect(
          pendingRoleRequests({'requestedRoles': ['elder', 'finance']},
              const UserAccess({UserRole.finance})),
          [UserRole.elder]);
    });

    test('damaged requests are ignored', () {
      expect(pendingRoleRequests(null, UserAccess.member), isEmpty);
      expect(pendingRoleRequests({}, UserAccess.member), isEmpty);
      expect(pendingRoleRequests({'requestedRole': 5, 'requestedRoles': 'elder'}, UserAccess.member),
          isEmpty);
      expect(pendingRoleRequests({'requestedRoles': [1, null, 'bishop']}, UserAccess.member),
          isEmpty);
    });

    test('approval adds the role, keeps existing ones and drops plain member', () {
      expect(rolesAfterApproval({UserRole.member}, UserRole.finance), ['finance']);
      expect(rolesAfterApproval({UserRole.elder}, UserRole.finance),
          ['elder', 'finance']);
    });

    test('the roles that open the money records are marked', () {
      expect(requestableRoles.where(opensFinances).toSet(),
          {UserRole.pastor, UserRole.finance, UserRole.oversight});
    });

    test('names are listed in plain words', () {
      expect(inWords(const []), '');
      expect(inWords(const ['Elder']), 'Elder');
      expect(inWords(const ['Elder', 'Deacon']), 'Elder and Deacon');
      expect(inWords(const ['Elder', 'Deacon', 'Secretariat']),
          'Elder, Deacon and Secretariat');
    });
  });

  group('what an Admin decision writes', () {
    final asking = {
      'role': 'member',
      'requestedRoles': ['elder', 'finance', 'secretariat'],
    };

    test('approving one grants only that one and keeps the others waiting', () {
      final u = roleDecisionUpdate(asking, UserRole.elder, approve: true);
      expect(u['roles'], ['elder']);
      expect(u['requestedRoles'], ['finance', 'secretariat']);
      expect(u['requestedRole'], isA<FieldValue>());
    });

    test('a second approval keeps the first', () {
      final afterFirst = {
        'roles': ['elder'],
        'requestedRoles': ['finance', 'secretariat'],
      };
      final u = roleDecisionUpdate(afterFirst, UserRole.secretariat, approve: true);
      expect(u['roles'], ['elder', 'secretariat']);
      expect(u['requestedRoles'], ['finance']);
    });

    test('declining grants nothing and keeps the others waiting', () {
      final u = roleDecisionUpdate(asking, UserRole.finance, approve: false);
      expect(u.containsKey('roles'), isFalse);
      expect(u['requestedRoles'], ['elder', 'secretariat']);
    });

    test('deciding the last one clears the request', () {
      final u = roleDecisionUpdate(
          {'requestedRoles': ['elder']}, UserRole.elder, approve: true);
      expect(u['requestedRoles'], isA<FieldValue>());
      expect(u['requestedRole'], isA<FieldValue>());
    });

    test('an older single request is carried over, not lost', () {
      final u = roleDecisionUpdate(
          {'requestedRole': 'finance', 'requestedRoles': ['elder']},
          UserRole.elder,
          approve: true);
      expect(u['requestedRoles'], ['finance']);
    });
  });

  group('signing up', () {
    Future<_SignUpSpy> openSignUp(WidgetTester tester) async {
      _tall(tester, 500);
      final spy = _SignUpSpy();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(spy)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
      ));
      await tester.tap(find.text('Need an account? Sign up'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Mary');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email or phone number'), 'm@x.org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      return spy;
    }

    Future<void> tick(WidgetTester tester, UserRole role) async {
      final chip = find.byKey(Key('role-chip-${role.name}'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      final button = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('a leader can tick every role they serve in', (tester) async {
      final spy = await openSignUp(tester);
      expect(find.text('You will join as a Member.'), findsOneWidget);
      await tick(tester, UserRole.secretariat);
      await tick(tester, UserRole.elder);
      await tick(tester, UserRole.finance);
      expect(find.textContaining('approve your Elder, Finance Officer and Secretariat'),
          findsOneWidget);
      await submit(tester);
      expect(spy.signUps.single, [
        'm@x.org',
        'Mary',
        {'elder', 'finance', 'secretariat'}
      ]);
      expect(
          find.textContaining(
              'request to be Elder, Finance Officer and Secretariat has been sent'),
          findsOneWidget);
    });

    testWidgets('a role can be unticked again', (tester) async {
      final spy = await openSignUp(tester);
      await tick(tester, UserRole.finance);
      await tick(tester, UserRole.finance);
      expect(find.text('You will join as a Member.'), findsOneWidget);
      await submit(tester);
      expect(spy.signUps.single[2], <String>{});
      expect(find.text('Account created!'), findsOneWidget);
    });

    testWidgets('every church role is offered, but never Admin', (tester) async {
      await openSignUp(tester);
      for (final role in requestableRoles) {
        expect(find.byKey(Key('role-chip-${role.name}')), findsOneWidget);
      }
      expect(find.byKey(const Key('role-chip-admin')), findsNothing);
      expect(find.byKey(const Key('role-chip-member')), findsNothing);
    });

    testWidgets('the log-in screen no longer asks which role to sign in as', (tester) async {
      _tall(tester, 500);
      final spy = _SignUpSpy();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(spy)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sign in as'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email or phone number'), 'm@x.org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(spy.signIns, ['m@x.org']);
      expect(find.text('Logged in!'), findsOneWidget);
    });
  });

  group('the Admin\'s approvals', () {
    Future<_FakeRoleRequests> pump(WidgetTester tester, List<RegisteredAccount> accounts) async {
      _tall(tester);
      final fake = _FakeRoleRequests();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          roleRequestServiceProvider.overrideWithValue(fake),
          userRoleProvider.overrideWith(
              (ref) => Stream.value(const UserAccess({UserRole.admin}))),
          registeredAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AccountRolesScreen()),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    const mary = RegisteredAccount('u1', 'Mary Phiri', 'mary@x.org', UserAccess.member,
        requestedRoles: [UserRole.elder, UserRole.finance]);
    const john = RegisteredAccount('u2', 'John Zulu', 'john@x.org', UserAccess.member);

    testWidgets('each role asked for is its own line', (tester) async {
      await pump(tester, const [mary, john]);
      expect(find.text('Waiting for your approval (2)'), findsOneWidget);
      expect(find.text('Wants to be Elder'), findsOneWidget);
      expect(find.textContaining('Wants to be Finance Officer'), findsOneWidget);
    });

    testWidgets('a role that opens the money records says so', (tester) async {
      await pump(tester, const [mary]);
      expect(find.textContaining("This opens the church's money records."), findsOneWidget);
    });

    testWidgets('one role can be approved and another declined', (tester) async {
      final fake = await pump(tester, const [mary]);
      await tester.tap(find.byKey(const Key('approve-u1-elder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('decline-u1-finance')));
      await tester.pumpAndSettle();
      expect(fake.approved, ['u1:elder']);
      expect(fake.declined, ['u1:finance']);
    });

    testWidgets('no approval box when nobody is waiting', (tester) async {
      await pump(tester, const [john]);
      expect(find.textContaining('Waiting for your approval'), findsNothing);
    });
  });

  group('asking for another role from inside the app', () {
    Future<_FakeRoleRequests> pump(
      WidgetTester tester, {
      UserAccess access = const UserAccess({UserRole.elder}),
      List<UserRole> waiting = const [],
      _FakeRoleRequests? service,
    }) async {
      _tall(tester);
      final fake = service ?? _FakeRoleRequests();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          roleRequestServiceProvider.overrideWithValue(fake),
          currentUserIdProvider.overrideWithValue('u1'),
          userRoleProvider.overrideWith((ref) => Stream.value(access)),
          ownPendingRoleRequestsProvider.overrideWithValue(waiting),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: RoleRequestCard())),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('only roles not held and not waiting are offered', (tester) async {
      await pump(tester, waiting: const [UserRole.finance]);
      expect(find.text('Waiting for the Admin: Finance Officer.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('request-role')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-chip-elder')), findsNothing); // held
      expect(find.byKey(const Key('role-chip-finance')), findsNothing); // waiting
      expect(find.byKey(const Key('role-chip-secretariat')), findsOneWidget);
      expect(find.byKey(const Key('role-chip-admin')), findsNothing);
    });

    testWidgets('several can be asked for at once', (tester) async {
      final fake = await pump(tester);
      await tester.tap(find.byKey(const Key('request-role')));
      await tester.pumpAndSettle();
      // nothing chosen yet, so nothing can be sent
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('send-role-request')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const Key('role-chip-secretariat')));
      await tester.tap(find.byKey(const Key('role-chip-finance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-role-request')));
      await tester.pumpAndSettle();
      expect(fake.asked.single, {UserRole.finance, UserRole.secretariat});
      expect(find.text('Sent. The Admin will approve Finance Officer and Secretariat.'),
          findsOneWidget);
    });

    testWidgets('cancelling sends nothing', (tester) async {
      final fake = await pump(tester);
      await tester.tap(find.byKey(const Key('request-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.asked, isEmpty);
    });

    testWidgets('a failure to send is said plainly', (tester) async {
      await pump(tester, service: _FakeRoleRequests()..failing = true);
      await tester.tap(find.byKey(const Key('request-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-chip-secretariat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-role-request')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not send your request'), findsOneWidget);
    });

    testWidgets('the button goes when there is nothing left to ask for', (tester) async {
      await pump(tester, access: UserAccess(requestableRoles.toSet()));
      expect(find.byKey(const Key('request-role')), findsNothing);
    });
  });

  testWidgets('the Home notice names every role still waiting', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ownPendingRoleRequestsProvider.overrideWithValue(
            const [UserRole.elder, UserRole.finance, UserRole.secretariat]),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: PendingRoleBanner())),
    ));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'You asked to be Elder, Finance Officer and Secretariat.'),
        findsOneWidget);
  });
}
