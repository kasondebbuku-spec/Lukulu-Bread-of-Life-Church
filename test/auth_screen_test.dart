import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/screens/auth_screen.dart';
import 'package:church_cms/services/auth_service.dart';

class _FakeAuthService implements AuthService {
  final signIns = <String>[];
  final resets = <String>[];

  @override
  Future<User?> signIn(String email, String password) async {
    signIns.add('$email|$password');
    return null;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  @override
  Future<User?> signUp(String email, String password, String name) async => null;

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
}
