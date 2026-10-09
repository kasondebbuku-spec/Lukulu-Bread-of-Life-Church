import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/repositories/income_form_repository.dart';

SundayIncomeForm _form({bool keyed = true}) => SundayIncomeForm(
      id: 'abc',
      date: DateTime(2026, 10, 4),
      service: ServiceType.evening,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown:
                  c == GivingCategory.tithe ? const {'100': 29, '10': 3} : const {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 40,
      women: 55,
      children: 20,
      preparedBy: 'Inambao Nanzila',
      checkedBy: 'Msiska Isaac',
      collectedBy: 'Mabai Mike',
      expenseEntries: const [ExpenseEntry(description: 'Missions', amount: 3180)],
      recordsKeyedById: keyed,
    );

Future<void> _pump(WidgetTester tester, Widget home, UserAccess role) async {
  // Tall enough that the whole (lazy) form list is built.
  tester.view.physicalSize = const Size(900, 14000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userRoleProvider.overrideWith((ref) => Stream.value(role)),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('derived records get predictable ids', () {
    expect(IncomeFormRepository.givingRecordId('abc', GivingCategory.tithe), 'abc_tithe');
    expect(IncomeFormRepository.attendanceRecordId('abc'), 'abc_attendance');
  });

  test('new forms are editable and the flag is saved and carried through copies', () {
    final form = _form();
    expect(form.canEdit, isTrue);
    expect(form.toMap()['recordsKeyedById'], true);
    expect(form.copyWithId('x').canEdit, isTrue);
    expect(_form(keyed: false).canEdit, isFalse);
  });

  testWidgets('finance sees Edit and Delete on an editable form', (tester) async {
    await _pump(tester, IncomeFormDetailScreen(form: _form()),
        const UserAccess({UserRole.finance}));
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.text('Read-only'), findsNothing);
  });

  testWidgets('view-only roles cannot edit or delete', (tester) async {
    await _pump(tester, IncomeFormDetailScreen(form: _form()),
        const UserAccess({UserRole.oversight}));
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets('forms saved before editing existed are read-only for everyone',
      (tester) async {
    await _pump(tester, IncomeFormDetailScreen(form: _form(keyed: false)),
        const UserAccess({UserRole.admin}));
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.text('Read-only'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation first', (tester) async {
    await _pump(tester, IncomeFormDetailScreen(form: _form()),
        const UserAccess({UserRole.finance}));
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this form?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this form?'), findsNothing);
    expect(find.byType(IncomeFormDetailScreen), findsOneWidget);
  });

  testWidgets('edit screen opens pre-filled with the saved values', (tester) async {
    await _pump(tester, SundayIncomeFormScreen(initialForm: _form()),
        const UserAccess({UserRole.finance}));
    expect(find.text('Edit Sunday Income Form'), findsOneWidget);

    String textOf(String value) =>
        tester.widgetList<EditableText>(find.byType(EditableText)).any(
                (e) => e.controller.text == value)
            ? value
            : '';

    expect(textOf('29'), '29'); // tithe K100 count
    expect(textOf('3'), '3'); // tithe K10 count
    expect(textOf('40'), '40'); // men
    expect(textOf('55'), '55'); // women
    expect(textOf('Inambao Nanzila'), 'Inambao Nanzila');
    expect(textOf('Missions'), 'Missions');
    expect(textOf('3180'), '3180');
  });
}
