import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/audit_actor_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/pledge_providers.dart';
import 'package:church_cms/core/providers/notifications_provider.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/giving_screen.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/features/giving/screens/income_forms_list_screen.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';
import 'package:church_cms/models/app_notification.dart';
import 'package:church_cms/models/audit_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/navigation/app_shell.dart';
import 'package:church_cms/repositories/income_form_repository.dart';
import 'package:church_cms/repositories/repository_providers.dart';

SundayIncomeForm _form({
  String enteredBy = '',
  String enteredByUid = '',
  String preparedBy = 'Prep Person',
  DateTime? createdAt,
  DateTime? date,
}) =>
    SundayIncomeForm(
      id: 'f',
      date: date ?? DateTime(2026, 11, 22),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown:
                  c == GivingCategory.tithe ? const {'100': 29} : const {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 1,
      women: 1,
      children: 1,
      preparedBy: preparedBy,
      checkedBy: 'b',
      collectedBy: 'c',
      enteredBy: enteredBy,
      enteredByUid: enteredByUid,
      createdAt: createdAt,
    );

/// Records what the screen asks it to save, or fails the way a refused write does.
class _FakeRepository implements IncomeFormRepository {
  _FakeRepository({this.failWith});
  final Object? failWith;
  final saved = <SundayIncomeForm>[];

  @override
  Future<String> saveAndCascade(SundayIncomeForm form,
      Map<String, double> valuesByKey,
      {required AuditActor actor}) async {
    if (failWith != null) throw failWith!;
    saved.add(form);
    return 'new-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('who entered a form', () {
    test('is saved with the form and read back', () {
      final map = _form(enteredBy: 'Mary Banda', enteredByUid: 'u1').toMap();
      expect(map['enteredBy'], 'Mary Banda');
      expect(map['enteredByUid'], 'u1');
    });

    test('is left out of the saved data when unknown', () {
      final map = _form().toMap();
      expect(map.containsKey('enteredBy'), isFalse);
      expect(map.containsKey('enteredByUid'), isFalse);
    });

    test('falls back to the prepared-by name on older forms', () {
      expect(_form(enteredBy: 'Mary Banda').enteredByLabel, 'Mary Banda');
      expect(_form(preparedBy: 'Peter Kabwe').enteredByLabel, 'Peter Kabwe');
    });

    test('is kept when the form is copied with its new id', () {
      final copy = _form(enteredBy: 'Mary Banda', enteredByUid: 'u1').copyWithId('x');
      expect(copy.enteredBy, 'Mary Banda');
      expect(copy.enteredByUid, 'u1');
    });
  });

  group('pressing Save', () {
    Future<void> pump(WidgetTester tester,
        {Size size = const Size(900, 14000),
        _FakeRepository? repository,
        AuditActor? actor}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          userRoleProvider.overrideWith(
              (ref) => Stream.value(const UserAccess({UserRole.finance}))),
          displayNameProvider.overrideWithValue('Mary Banda'),
          auditActorProvider.overrideWithValue(actor),
          if (repository != null)
            incomeFormRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: const SundayIncomeFormScreen()),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> fillRequired(WidgetTester tester) async {
      Future<void> type(String label, String text) =>
          tester.enterText(find.widgetWithText(TextFormField, label), text);
      await type('Men', '40');
      await type('Women', '55');
      await type('Children', '20');
      await type('Checked By', 'Elder Kabwe');
      await type('Collected By', 'Mabai Mike');
    }

    testWidgets('with required fields empty, says exactly what is missing',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Save Form'));
      await tester.pumpAndSettle();
      // Prepared By is pre-filled with the signed-in name, so it is not missing.
      expect(
          find.text(
              'Not saved yet. Please fill in: Men, Women, Children, Checked By, Collected By.'),
          findsOneWidget);
    });

    testWidgets('takes the person to the first section that needs filling in',
        (tester) async {
      await pump(tester, size: const Size(800, 900));
      final list = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Form'));
      await tester.pumpAndSettle();

      // Attendance is the first empty section, and is now on screen.
      final top = tester.getTopLeft(find.text('Attendance')).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(900));
    });

    testWidgets('not signed in: says nothing was saved, and why', (tester) async {
      await pump(tester);
      await fillRequired(tester);
      await tester.tap(find.text('Save Form'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Could not save: You must be signed in to save a form. Nothing was saved.'),
          findsOneWidget);
    });

    testWidgets('a refused write says the account is not allowed', (tester) async {
      final repo = _FakeRepository(
          failWith: FirebaseException(
              plugin: 'cloud_firestore', code: 'permission-denied'));
      await pump(tester,
          repository: repo, actor: const AuditActor(uid: 'u1', name: 'Mary Banda'));
      await fillRequired(tester);
      await tester.tap(find.text('Save Form'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Could not save: your account is not allowed to save Sunday income forms. Nothing was saved.'),
          findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('a lost connection says so', (tester) async {
      final repo = _FakeRepository(
          failWith:
              FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      await pump(tester,
          repository: repo, actor: const AuditActor(uid: 'u1', name: 'Mary Banda'));
      await fillRequired(tester);
      await tester.tap(find.text('Save Form'));
      await tester.pumpAndSettle();
      expect(find.textContaining('there is no connection right now'), findsOneWidget);
    });

    testWidgets('a good save records who entered it, tells them, and shows the form',
        (tester) async {
      final repo = _FakeRepository();
      await pump(tester,
          repository: repo, actor: const AuditActor(uid: 'u1', name: 'Mary Banda'));
      await fillRequired(tester);
      await tester.tap(find.text('Save Form'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.saved.single.enteredBy, 'Mary Banda');
      expect(repo.saved.single.enteredByUid, 'u1');
      expect(find.byType(IncomeFormDetailScreen), findsOneWidget);
      expect(
          find.text('Saved. You can find it again in Giving > Sunday Income Forms.'),
          findsOneWidget);
    });
  });

  group('the list of saved forms', () {
    testWidgets('shows who entered each one and when, with the net amount',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          incomeFormsProvider.overrideWith((ref) => Stream.value([
                _form(
                    enteredBy: 'Mary Banda',
                    createdAt: DateTime(2026, 11, 22, 10, 42)),
                _form(preparedBy: 'Peter Kabwe', date: DateTime(2026, 11, 15)),
              ])),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: const IncomeFormsListScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Entered by Mary Banda'), findsOneWidget);
      expect(find.textContaining('Saved Nov 22, 2026 10:42'), findsOneWidget);
      // An older form has no recorded saver, so the prepared-by name is shown.
      expect(find.textContaining('Entered by Peter Kabwe'), findsOneWidget);
      expect(find.textContaining('Net Amount: ZMW 2900.00'), findsNWidgets(2));
    });
  });

  group('the Giving screen', () {
    testWidgets('puts the saved Sunday forms one tap away, not only behind an icon',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userRoleProvider.overrideWith(
              (ref) => Stream.value(const UserAccess({UserRole.finance}))),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          givingRecordsProvider.overrideWith((ref) => Stream.value([])),
          incomeFormsProvider.overrideWith((ref) => Stream.value([
                _form(enteredBy: 'Mary Banda', createdAt: DateTime(2026, 11, 22, 10, 42)),
              ])),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const GivingScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sunday Income Forms'), findsOneWidget);
      expect(find.text('What was entered each Sunday, by whom'), findsOneWidget);
      // Pledges are one tap away too.
      expect(find.text('Pledges'), findsOneWidget);
      expect(find.text('Who has pledged, what is paid, what is overdue'), findsOneWidget);

      await tester.tap(find.text('Sunday Income Forms'));
      await tester.pumpAndSettle();
      expect(find.byType(IncomeFormsListScreen), findsOneWidget);
      expect(find.textContaining('Entered by Mary Banda'), findsOneWidget);
    });
  });

  group('the dashboard', () {
    Future<void> pumpHome(WidgetTester tester, UserAccess role) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: [
        userRoleProvider.overrideWith((ref) => Stream.value(role)),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        membersProvider.overrideWith((ref) => Stream.value([])),
        givingRecordsProvider.overrideWith((ref) => Stream.value([])),
        attendanceRecordsProvider.overrideWith((ref) => Stream.value([])),
        eventsProvider.overrideWith((ref) => Stream.value([])),
        announcementsProvider.overrideWith((ref) => Stream.value([])),
        myPledgeProgressProvider.overrideWithValue(const []),
        prayerRequestsProvider.overrideWith((ref) => Stream.value([])),
        incomeFormsProvider.overrideWith((ref) => Stream.value([
              _form(
                  enteredBy: 'Mary Banda',
                  createdAt: DateTime(2026, 11, 22, 10, 42)),
            ])),
      ], child: MaterialApp(theme: AppTheme.lightTheme, home: const AppShell())));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the latest Sunday form and who entered it, for those who see giving',
        (tester) async {
      await pumpHome(tester, const UserAccess({UserRole.admin}));
      expect(find.text('Sunday Income Forms'), findsWidgets);
      expect(find.text('Latest: Nov 22, 2026 by Mary Banda'), findsOneWidget);
    });

    testWidgets('is not shown to a member', (tester) async {
      await pumpHome(tester, UserAccess.member);
      expect(find.text('Latest: Nov 22, 2026 by Mary Banda'), findsNothing);
    });
  });

  group('notifications for saved forms', () {
    ProviderContainer container(UserAccess role, List<SundayIncomeForm> forms) {
      final c = ProviderContainer(overrides: [
        userRoleProvider.overrideWith((ref) => Stream.value(role)),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        announcementsProvider.overrideWith((ref) => Stream.value([])),
        myPledgeProgressProvider.overrideWithValue(const []),
        eventsProvider.overrideWith((ref) => Stream.value([])),
        incomeFormsProvider.overrideWith((ref) => Stream.value(forms)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    final recent = _form(enteredBy: 'Mary Banda', createdAt: DateTime.now());

    test('people who see giving are told a Sunday form was saved', () async {
      final c = container(const UserAccess({UserRole.pastor}), [recent]);
      // Let the streams deliver.
      c.listen(userRoleProvider, (_, __) {});
      c.listen(incomeFormsProvider, (_, __) {});
      c.listen(announcementsProvider, (_, __) {});
      c.listen(eventsProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final items = c.read(notificationsProvider);
      expect(items, hasLength(1));
      expect(items.single.kind, NotificationKind.incomeForm);
      expect(items.single.title, 'Sunday Income Form saved');
      expect(items.single.detail, contains('Grand Total ZMW 2900.00'));
      expect(items.single.detail, contains('entered by Mary Banda'));
    });

    test('an ordinary member is never told', () async {
      final c = container(UserAccess.member, [recent]);
      c.listen(userRoleProvider, (_, __) {});
      c.listen(incomeFormsProvider, (_, __) {});
      c.listen(announcementsProvider, (_, __) {});
      c.listen(eventsProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(notificationsProvider), isEmpty);
    });

    test('an old form is no longer news', () async {
      final old = _form(
          enteredBy: 'Mary Banda',
          createdAt: DateTime.now().subtract(const Duration(days: 45)));
      final c = container(const UserAccess({UserRole.admin}), [old]);
      c.listen(userRoleProvider, (_, __) {});
      c.listen(incomeFormsProvider, (_, __) {});
      c.listen(announcementsProvider, (_, __) {});
      c.listen(eventsProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(notificationsProvider), isEmpty);
    });
  });
}
