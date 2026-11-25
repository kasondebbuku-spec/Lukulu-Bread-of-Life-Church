import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/models/ministry_position.dart';
import 'package:church_cms/screens/auth_screen.dart';
import 'package:church_cms/services/auth_service.dart';

class _FakeAuthService implements AuthService {
  final signIns = <String>[];
  final resets = <String>[];
  final signUps = <List<String?>>[];
  final phones = <String?>[];
  final positions = <MinistryPosition?>[];

  @override
  Future<User?> signIn(String email, String password) async {
    signIns.add('$email|$password');
    return null;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  @override
  Future<User?> signUp(String email, String password, String name,
      {UserRole? requestedRole,
      MinistryPosition? requestedPosition,
      String? phone}) async {
    signUps.add([email, name, requestedRole?.name]);
    phones.add(phone);
    positions.add(requestedPosition);
    return null;
  }

  @override
  Future<UserAccess> loadAccess(String uid) async => UserAccess.member;

  @override
  Future<void> signOut() async {}

  @override
  User? get currentUser => null;
}

void main() {
  late _FakeAuthService fake;

  Future<void> pumpAuth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fake = _FakeAuthService();
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('pressing Enter on the password field logs in', (tester) async {
    await pumpAuth(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), ' a@b.com ');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fake.signIns, ['a@b.com|secret1']);
  });

  testWidgets('forgot password sends a reset link to the typed email',
      (tester) async {
    await pumpAuth(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'me@church.org');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // The dialog is pre-filled from the login form.
    final dialogField = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    expect(tester.widget<TextField>(dialogField).controller!.text, 'me@church.org');
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(fake.resets, ['me@church.org']);
    expect(find.textContaining('reset link is on its way'), findsOneWidget);
  });

  testWidgets('forgot password is hidden on the sign-up form', (tester) async {
    await pumpAuth(tester);
    await tester.tap(find.text('Need an account? Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing);
  });

  group('signing in and up with a phone number', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await pumpAuth(tester);
      await tester.tap(find.text('Need an account? Sign up'));
      await tester.pumpAndSettle();
    }

    Future<void> signUp(WidgetTester tester) async {
      final button = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('the sign-in form offers a phone number instead of an email', (tester) async {
      await pumpAuth(tester);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle-phone')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Phone number'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
      expect(find.text('Use an email instead'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle-phone')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    });

    testWidgets('a phone number and password log in', (tester) async {
      await pumpAuth(tester);
      await tester.tap(find.byKey(const Key('toggle-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), '0971 234 567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.signIns, ['0971 234 567|secret1']);
    });

    testWidgets('a phone number typed into the email box still logs in', (tester) async {
      await pumpAuth(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), '0971234567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.signIns, ['0971234567|secret1']);
    });

    testWidgets('something that is not a phone number is turned away', (tester) async {
      await pumpAuth(tester);
      await tester.tap(find.byKey(const Key('toggle-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), 'abc');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid phone number'), findsOneWidget);
      expect(fake.signIns, isEmpty);
    });

    testWidgets('signing up with a phone number passes it on, tidied, and no email', (tester) async {
      await openSignUp(tester);
      await tester.tap(find.byKey(const Key('toggle-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'John Phiri');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), '097 123 4567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await signUp(tester);
      expect(fake.phones, ['260971234567']);
      expect(fake.signUps.single[1], 'John Phiri');
      expect(find.text('Account created!'), findsOneWidget);
    });

    testWidgets('an email sign-up passes no phone number', (tester) async {
      await openSignUp(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Mary Banda');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'mary@x.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
      await signUp(tester);
      expect(fake.phones, [null]);
      expect(fake.signUps.single[0], 'mary@x.com');
    });

    testWidgets('forgot password explains that a phone account has no reset link', (tester) async {
      await pumpAuth(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), '0971234567');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();
      expect(find.text('Phone number accounts'), findsOneWidget);
      expect(find.textContaining('ask the Admin'), findsOneWidget);
      expect(fake.resets, isEmpty);
    });
  });

  group('asking for a ministry position at sign-up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await pumpAuth(tester);
      await tester.tap(find.text('Need an account? Sign up'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Ruth Banda');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ruth@x.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    }

    Future<void> signUp(WidgetTester tester) async {
      final button = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('the ministry fields appear only when ticked', (tester) async {
      await openSignUp(tester);
      expect(find.byKey(const Key('ministry-title')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('leads-ministry')));
      await tester.tap(find.byKey(const Key('leads-ministry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ministry-choice')), findsOneWidget);
      expect(find.byKey(const Key('ministry-title')), findsOneWidget);
    });

    testWidgets('the position is passed on for the Admin to approve', (tester) async {
      await openSignUp(tester);
      await tester.ensureVisible(find.byKey(const Key('leads-ministry')));
      await tester.tap(find.byKey(const Key('leads-ministry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ministry-choice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choir').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ministry-title')), 'Leader');
      await signUp(tester);
      expect(fake.positions.single,
          const MinistryPosition(ministry: 'Choir', title: 'Leader'));
      expect(find.textContaining('Choir · Leader'), findsOneWidget);
      expect(find.textContaining('sent to the Admin'), findsOneWidget);
    });

    testWidgets('a ticked box with nothing filled in stops the sign-up', (tester) async {
      await openSignUp(tester);
      await tester.ensureVisible(find.byKey(const Key('leads-ministry')));
      await tester.tap(find.byKey(const Key('leads-ministry')));
      await tester.pumpAndSettle();
      await signUp(tester);
      expect(find.text('Choose the ministry'), findsOneWidget);
      expect(fake.signUps, isEmpty);
    });

    testWidgets('left unticked, no position is passed', (tester) async {
      await openSignUp(tester);
      await signUp(tester);
      expect(fake.positions, [null]);
    });

    testWidgets('the ministry choice is not offered when logging in', (tester) async {
      await pumpAuth(tester);
      expect(find.byKey(const Key('leads-ministry')), findsNothing);
    });
  });
}
