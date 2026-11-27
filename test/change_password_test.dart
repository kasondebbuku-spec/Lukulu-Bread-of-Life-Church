// These stand-ins have to implement Firebase's sealed classes to replace them.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/admin_contact_providers.dart';
import 'package:church_cms/core/providers/auth_providers.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/notifications_provider.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/account/screens/change_password_screen.dart';
import 'package:church_cms/features/account/widgets/admin_whatsapp_button.dart';
import 'package:church_cms/features/dashboard/widgets/dashboard_header.dart';
import 'package:church_cms/models/admin_help.dart';
import 'package:church_cms/navigation/app_sidebar.dart';
import 'package:church_cms/navigation/nav_destination.dart';
import 'package:church_cms/screens/auth_screen.dart';
import 'package:church_cms/services/auth_service.dart';

const _admin = '260966000111';

// ---- stand-ins for Firebase ----
class _User implements User {
  _User(this.log, {this.address = 'mary@x.org', this.refuse});
  final List<String> log;
  final String? address;

  /// The error code to refuse the current password with.
  final String? refuse;

  @override
  String? get email => address;

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    final c = credential as EmailAuthCredential;
    log.add('check ${c.email} ${c.password}');
    if (refuse != null) throw FirebaseAuthException(code: refuse!);
    return _Credential();
  }

  @override
  Future<void> updatePassword(String newPassword) async => log.add('set $newPassword');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  _Auth(this.user);
  final User? user;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeService implements AuthService {
  final changes = <String>[];
  final resets = <String>[];
  Object? failure;

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (failure != null) throw failure!;
    changes.add('$currentPassword|$newPassword');
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('changing a password with Firebase', () {
    AuthService service(User? user) =>
        AuthService(auth: _Auth(user), firestore: _NoFirestore());

    test('checks the current password first, then sets the new one', () async {
      final log = <String>[];
      await service(_User(log)).changePassword('old-secret', 'new-secret');
      expect(log, ['check mary@x.org old-secret', 'set new-secret']);
    });

    test('a wrong current password changes nothing', () async {
      final log = <String>[];
      await expectLater(
          service(_User(log, refuse: 'invalid-credential'))
              .changePassword('guess', 'new-secret'),
          throwsA(isA<FirebaseAuthException>()));
      expect(log.where((x) => x.startsWith('set')), isEmpty);
    });

    test('a phone account is checked against its private sign-in address', () async {
      final log = <String>[];
      await service(_User(log, address: '260971234567@phone.lukulu-bread-of-life.app'))
          .changePassword('old-secret', 'new-secret');
      expect(log.first,
          'check 260971234567@phone.lukulu-bread-of-life.app old-secret');
    });

    test('nobody signed in cannot change anything', () async {
      for (final user in [null, _User(<String>[], address: null)]) {
        await expectLater(
            service(user).changePassword('a', 'bbbbbb'),
            throwsA(isA<FirebaseAuthException>()
                .having((e) => e.code, 'code', 'no-current-user')));
      }
    });
  });

  group('the Change password screen', () {
    Future<_FakeService> open(WidgetTester tester,
        {Object? failure, String email = 'mary@x.org'}) async {
      _tall(tester);
      final service = _FakeService()..failure = failure;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(service),
          authStateChangesProvider
              .overrideWith((ref) => Stream.value(_User(<String>[], address: email))),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return service;
    }

    Future<void> fill(WidgetTester tester,
        {String current = 'old-secret', String next = 'new-secret', String? again}) async {
      await tester.enterText(find.byKey(const Key('current-password')), current);
      await tester.enterText(find.byKey(const Key('new-password')), next);
      await tester.enterText(find.byKey(const Key('confirm-password')), again ?? next);
      await tester.tap(find.byKey(const Key('save-password')));
      await tester.pumpAndSettle();
    }

    testWidgets('saves a new password, says so, and goes back', (tester) async {
      final service = await open(tester);
      await fill(tester);
      expect(service.changes, ['old-secret|new-secret']);
      expect(find.textContaining('Password changed'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsNothing);
    });

    testWidgets('uses passwords exactly as typed, spaces and all', (tester) async {
      final service = await open(tester);
      await fill(tester, current: ' old one ', next: ' new one ');
      expect(service.changes, [' old one | new one ']);
    });

    testWidgets('the current password must be given', (tester) async {
      final service = await open(tester);
      await fill(tester, current: '');
      expect(find.text('Enter your current password'), findsOneWidget);
      expect(service.changes, isEmpty);
    });

    testWidgets('the new one needs at least six characters', (tester) async {
      final service = await open(tester);
      await fill(tester, next: 'abc');
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(service.changes, isEmpty);
    });

    testWidgets('the new one must be different', (tester) async {
      final service = await open(tester);
      await fill(tester, next: 'old-secret');
      expect(find.text('Choose a password different from the current one'), findsOneWidget);
      expect(service.changes, isEmpty);
    });

    testWidgets('the two new passwords must match', (tester) async {
      final service = await open(tester);
      await fill(tester, next: 'new-secret', again: 'new-secrte');
      expect(find.text('The two new passwords do not match'), findsOneWidget);
      expect(service.changes, isEmpty);
    });

    testWidgets('a wrong current password is said plainly, and the screen stays', (tester) async {
      await open(tester, failure: FirebaseAuthException(code: 'wrong-password'));
      await fill(tester);
      expect(
          find.text(
              'Your current password is not right. Your password has not been changed.'),
          findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('any other failure says nothing was changed', (tester) async {
      await open(tester, failure: StateError('boom'));
      await fill(tester);
      expect(find.text('Could not change your password. It has not been changed.'),
          findsOneWidget);
    });

    testWidgets('the passwords can be shown', (tester) async {
      await open(tester);
      bool hidden() => tester
          .widget<EditableText>(find.descendant(
              of: find.byKey(const Key('new-password')),
              matching: find.byType(EditableText)))
          .obscureText;
      expect(hidden(), isTrue);
      await tester.tap(find.byKey(const Key('show-passwords')));
      await tester.pumpAndSettle();
      expect(hidden(), isFalse);
    });

    testWidgets('names a phone account by its number, not the private address', (tester) async {
      await open(tester, email: '260971234567@phone.lukulu-bread-of-life.app');
      expect(find.text('For the account +260 97 123 4567'), findsOneWidget);
      expect(find.textContaining('@phone.'), findsNothing);
    });

    test('each reason has plain words', () {
      expect(changePasswordProblem('invalid-credential'), contains('current password is not right'));
      expect(changePasswordProblem('weak-password'), contains('too weak'));
      expect(changePasswordProblem('too-many-requests'), contains('wait'));
      expect(changePasswordProblem('network-request-failed'), contains('No connection'));
      expect(changePasswordProblem('requires-recent-login'), contains('log in again'));
      expect(changePasswordProblem('something-new'), contains('has not been changed'));
    });
  });

  group('where to find it', () {
    testWidgets('in the account menu on Home', (tester) async {
      _tall(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [unreadNotificationsProvider.overrideWithValue(0)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DashboardHeader(
                greeting: 'Hello',
                userName: 'Mary',
                role: UserAccess.member,
                onLogout: () {}),
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Logout'), findsOneWidget);
      await tester.tap(find.text('Change password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('in the profile menu at the bottom of the side menu', (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Row(children: [
              AppSidebar(
                destinations: [
                  NavDestination(
                      label: 'Home', icon: Icons.home, builder: () => const SizedBox()),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
                userName: 'Mary',
                roleLabel: 'Member',
                onLogout: () {},
              ),
            ]),
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });

  group('the WhatsApp message', () {
    test('names the phone number in the app\'s spacing', () {
      final m = passwordHelpMessage('0971234567');
      expect(m, contains('forgotten my password'));
      expect(m, contains('My phone number on the app is +260 97 123 4567.'));
      expect(m.trimRight(), endsWith('My name is:'));
    });

    test('names an email, or nothing when the box is empty or unfinished', () {
      expect(passwordHelpMessage(' mary@x.org '), contains('My email on the app is mary@x.org.'));
      for (final typed in ['', '   ', '097', 'mary']) {
        final m = passwordHelpMessage(typed);
        expect(m, isNot(contains('on the app is')), reason: typed);
      }
    });

    test('the link opens a chat with the Admin with that message typed', () {
      final uri = adminWhatsAppLink(_admin, typed: '0971234567');
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/$_admin');
      expect(uri.queryParameters['text'], passwordHelpMessage('0971234567'));
    });

    test('the set number is read with the country code, ready for the link', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Guards against a typo in admin_contact.dart: a wrong or unfinished number
      // would silently hide the button or open a chat with someone else.
      expect(container.read(adminWhatsAppProvider), '260972357358');
    });
  });

  group('the WhatsApp button', () {
    Future<List<Uri>> pump(WidgetTester tester,
        {String? number = _admin, bool opens = true, bool throws = false}) async {
      final opened = <Uri>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          adminWhatsAppProvider.overrideWithValue(number),
          externalLinkProvider.overrideWithValue((uri) async {
            if (throws) throw StateError('no handler');
            opened.add(uri);
            return opens;
          }),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: AdminWhatsAppButton(typed: '0971234567'))),
      ));
      return opened;
    }

    testWidgets('is hidden without a number', (tester) async {
      await pump(tester, number: null);
      expect(find.byKey(const Key('whatsapp-admin')), findsNothing);
    });

    testWidgets('opens WhatsApp to the Admin', (tester) async {
      final opened = await pump(tester);
      await tester.tap(find.byKey(const Key('whatsapp-admin')));
      await tester.pumpAndSettle();
      expect(opened.single, adminWhatsAppLink(_admin, typed: '0971234567'));
      expect(find.byKey(const Key('whatsapp-failed')), findsNothing);
    });

    for (final throws in [false, true]) {
      testWidgets('gives the number if WhatsApp does not open (throws: $throws)',
          (tester) async {
        await pump(tester, opens: false, throws: throws);
        await tester.tap(find.byKey(const Key('whatsapp-admin')));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'WhatsApp did not open. Message the Admin on +260 96 600 0111.'),
            findsOneWidget);
      });
    }
  });

  group('under Forgot password', () {
    Future<(List<Uri>, _FakeService)> open(WidgetTester tester,
        {String? number = _admin}) async {
      _tall(tester);
      final opened = <Uri>[];
      final service = _FakeService();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(service),
          adminWhatsAppProvider.overrideWithValue(number),
          externalLinkProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
      ));
      await tester.pumpAndSettle();
      return (opened, service);
    }

    Future<void> tapForgot(WidgetTester tester, {String typed = ''}) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email or phone number'), typed);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
    }

    testWidgets('the button is there, and sends nothing by itself', (tester) async {
      final (opened, service) = await open(tester);
      await tapForgot(tester);
      expect(find.byKey(const Key('whatsapp-admin')), findsOneWidget);
      expect(opened, isEmpty);
      expect(service.resets, isEmpty);
    });

    testWidgets('it carries the number typed on the log-in screen', (tester) async {
      final (opened, service) = await open(tester);
      await tapForgot(tester, typed: '0971234567');
      await tester.tap(find.byKey(const Key('whatsapp-admin')));
      await tester.pumpAndSettle();
      expect(opened.single.queryParameters['text'], contains('+260 97 123 4567'));
      expect(service.resets, isEmpty);
    });

    testWidgets('a phone account is told to ask the Admin, with the button', (tester) async {
      await open(tester);
      await tapForgot(tester, typed: '0971234567');
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();
      expect(find.text('Phone number accounts'), findsOneWidget);
      expect(find.textContaining('ask the Admin for help'), findsOneWidget);
      expect(find.byKey(const Key('whatsapp-admin')), findsOneWidget);
    });

    testWidgets('with no number set, there is no button', (tester) async {
      await open(tester, number: null);
      await tapForgot(tester);
      expect(find.byKey(const Key('whatsapp-admin')), findsNothing);
    });
  });
}
