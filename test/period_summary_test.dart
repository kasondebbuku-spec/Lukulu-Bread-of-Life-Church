import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/pdf/period_summary_pdf.dart';
import 'package:church_cms/features/giving/screens/period_summary_screen.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/period_summary.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/repositories/repository_providers.dart';

const _values = {'100': 100.0, '10': 10.0, '1': 1.0};

GivingRecord _give(DateTime date, double amount,
        {GivingCategory? category = GivingCategory.tithe, String currency = 'ZMW'}) =>
    GivingRecord(
      id: '',
      memberName: 'x',
      amount: amount,
      currency: currency,
      date: date,
      category: category,
    );

SundayIncomeForm _form(DateTime date,
        {int tithe100 = 10, int men = 10, int women = 10, int children = 5, int reserve = 700}) =>
    SundayIncomeForm(
      id: '',
      date: date,
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown: c == GivingCategory.tithe ? {'100': tithe100} : const {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: men,
      women: women,
      children: children,
      preparedBy: 'a',
      checkedBy: 'b',
      collectedBy: 'c',
      natsaveBlock: const CategoryBlock(denominationBreakdown: {'10': 5}),
      expensesReserveBlock: CategoryBlock(denominationBreakdown: {'1': reserve}),
      expenseEntries: const [ExpenseEntry(description: 'x', amount: 500)],
    );

void main() {
  final records = [
    _give(DateTime(2026, 10, 4), 1000), // Sunday, October
    _give(DateTime(2026, 10, 4), 300, category: GivingCategory.offering),
    _give(DateTime(2026, 10, 11), 500),
    _give(DateTime(2026, 10, 12), 50, category: null), // uncategorized
    _give(DateTime(2026, 10, 12), 999, currency: 'USD'), // other currency, ignored
    _give(DateTime(2026, 9, 27), 777), // September
    _give(DateTime(2025, 10, 5), 111), // previous year
  ];
  final forms = [
    // 20% of 1000 = 200 and 700 - 500 = 200 -> reconciles.
    _form(DateTime(2026, 10, 4)),
    _form(DateTime(2026, 10, 11), tithe100: 20, men: 20, women: 20, children: 10),
    _form(DateTime(2026, 9, 27)),
  ];

  PeriodSummary month() => PeriodSummary.compute(
      start: DateTime(2026, 10),
      isYear: false,
      records: records,
      forms: forms,
      valuesByKey: _values);

  test('a month only counts its own ZMW records, by category', () {
    final s = month();
    expect(s.categoryTotals[GivingCategory.tithe], 1500);
    expect(s.categoryTotals[GivingCategory.offering], 300);
    expect(s.otherTotal, 50);
    expect(s.grandTotal, 1850);
    expect(s.label, 'October 2026');
    expect(s.pdfFilename, 'period-summary-2026-10.pdf');
  });

  test('weekly breakdown is grouped by Sunday, oldest first', () {
    final weeks = month().weeks;
    expect(weeks.map((w) => w.sunday), [DateTime(2026, 10, 4), DateTime(2026, 10, 11)]);
    expect(weeks.map((w) => w.total), [1300, 550]);
  });

  test('forms in the month feed deposits, expenses and attendance', () {
    final s = month();
    expect(s.serviceCount, 2);
    expect(s.formTotals.titheOfTithes, 200 + 400);
    expect(s.formTotals.natsaveDeposit, 50 + 50);
    expect(s.formTotals.totalExpenses, 1000);
    expect(s.totalAttendance, 25 + 50);
    expect(s.averageAttendance, 37.5);
  });

  test('a year spans every month and excludes other years', () {
    final s = PeriodSummary.compute(
        start: DateTime(2026),
        isYear: true,
        records: records,
        forms: forms,
        valuesByKey: _values);
    expect(s.categoryTotals[GivingCategory.tithe], 1500 + 777);
    expect(s.serviceCount, 3);
    expect(s.label, '2026');
    expect(s.pdfFilename, 'period-summary-2026.pdf');
  });

  test('an empty period is all zeros without dividing by zero', () {
    final s = PeriodSummary.compute(
        start: DateTime(2024, 3),
        isYear: false,
        records: records,
        forms: forms,
        valuesByKey: _values);
    expect(s.grandTotal, 0);
    expect(s.averageAttendance, 0);
    expect(s.weeks, isEmpty);
    expect(s.formTotals.hasForms, isFalse);
  });

  test('the summary PDF renders and uses only plain ASCII text', () async {
    expect((await buildPeriodSummaryPdf(month())).isNotEmpty, isTrue);
    final empty = PeriodSummary.compute(
        start: DateTime(2024, 3),
        isYear: false,
        records: const [],
        forms: const [],
        valuesByKey: _values);
    expect((await buildPeriodSummaryPdf(empty)).isNotEmpty, isTrue);

    final source = File('lib/features/giving/pdf/period_summary_pdf.dart').readAsStringSync();
    expect(source.runes.where((r) => r > 126), isEmpty);
  });

  testWidgets('the screen shows the month, switches to year, and steps back', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 5);
    final lastMonth = DateTime(now.year, now.month - 1, 5);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        givingRecordsProvider.overrideWith((ref) => Stream.value([
              _give(thisMonth, 1234),
              _give(lastMonth, 4321),
            ])),
        incomeFormsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const PeriodSummaryScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ZMW 1234.00'), findsWidgets); // this month
    expect(find.text('ZMW 4321.00'), findsNothing);

    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('ZMW 4321.00'), findsWidgets);
    expect(find.text('ZMW 1234.00'), findsNothing);

    // The next-month arrow is disabled once we're at the current month.
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('ZMW 1234.00'), findsWidgets);
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year}'), findsOneWidget);
  });
}
