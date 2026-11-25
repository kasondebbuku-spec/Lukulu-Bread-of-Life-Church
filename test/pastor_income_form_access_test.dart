import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/pledge_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/giving_screen.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/repositories/repository_providers.dart';

SundayIncomeForm _form() => SundayIncomeForm(
      id: 'f',
      date: DateTime(2026, 11, 22),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown:
                  c == GivingCategory.tithe ? const {'100': 5} : const {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 1,
      women: 1,
      children: 1,
      preparedBy: 'Prep Person',
      checkedBy: 'b',
      collectedBy: 'c',
    );

Future<void> _pump(WidgetTester tester, UserRole role, Widget home) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userRoleProvider.overrideWith((ref) => Stream.value(UserAccess({role}))),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      givingRecordsProvider.overrideWith((ref) => Stream.value([])),
      incomeFormsProvider.overrideWith((ref) => Stream.value([])),
      allPledgeProgressProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('who may enter a Sunday Income Form', () {
    test('Admin, Finance and the Pastor can; no one else', () {
      final may = UserRole.values.where((r) => r.canEnterIncomeForms).toSet();
      expect(may, {UserRole.admin, UserRole.finance, UserRole.pastor});
    });

    test('the Pastor still cannot change other financial records', () {
      expect(UserRole.pastor.canManageGiving, isFalse);
      expect(UserRole.pastor.canViewGiving, isTrue);
    });

    test('a person with several roles gets it from any of them', () {
      expect(const UserAccess({UserRole.member, UserRole.pastor}).canEnterIncomeForms, isTrue);
      expect(const UserAccess({UserRole.elder, UserRole.oversight}).canEnterIncomeForms, isFalse);
    });
  });

  group('the Giving screen', () {
    testWidgets('gives the Pastor a button straight to the income form', (tester) async {
      await _pump(tester, UserRole.pastor, const GivingScreen());
      expect(find.byKey(const Key('add-income-form')), findsOneWidget);
      expect(find.text('Sunday Income Form'), findsOneWidget);
      // not the general "add" button that offers named contributions too
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('that button opens the income form', (tester) async {
      await _pump(tester, UserRole.pastor, const GivingScreen());
      await tester.tap(find.byKey(const Key('add-income-form')));
      await tester.pumpAndSettle();
      expect(find.byType(SundayIncomeFormScreen), findsOneWidget);
    });

    testWidgets('keeps the full add menu for Finance', (tester) async {
      await _pump(tester, UserRole.finance, const GivingScreen());
      expect(find.byKey(const Key('add-income-form')), findsNothing);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('Record Contribution'), findsOneWidget);
      expect(find.text('Sunday Income Form'), findsOneWidget);
    });

    for (final role in [UserRole.oversight, UserRole.elder]) {
      testWidgets('shows no add button to ${role.name}', (tester) async {
        await _pump(tester, role, const GivingScreen());
        expect(find.byKey(const Key('add-income-form')), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('a saved form', () {
    testWidgets('the Pastor can correct it but not delete it', (tester) async {
      await _pump(tester, UserRole.pastor, IncomeFormDetailScreen(form: _form()));
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('Finance can correct and delete it', (tester) async {
      await _pump(tester, UserRole.finance, IncomeFormDetailScreen(form: _form()));
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('Financial Oversight can only look', (tester) async {
      await _pump(tester, UserRole.oversight, IncomeFormDetailScreen(form: _form()));
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
    });
  });
}
