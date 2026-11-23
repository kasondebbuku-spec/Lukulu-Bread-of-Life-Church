import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/core/utils/date_format.dart';
import 'package:church_cms/core/utils/week_utils.dart';
import 'package:church_cms/features/giving/pdf/period_summary_pdf.dart';
import 'package:church_cms/features/giving/screens/period_summary_screen.dart';
import 'package:church_cms/features/giving/screens/weekly_statement_screen.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/period_summary.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/models/trend.dart';
import 'package:church_cms/models/week_summary.dart';
import 'package:church_cms/repositories/repository_providers.dart';

Trend _t(double now, double before) => Trend(current: now, previous: before);

GivingRecord _give(DateTime date, double amount,
        {GivingCategory category = GivingCategory.tithe}) =>
    GivingRecord(
        id: '',
        memberName: 'x',
        amount: amount,
        currency: 'ZMW',
        date: date,
        category: category);

SundayIncomeForm _form(DateTime date,
        {int men = 10,
        int women = 10,
        int children = 5,
        List<ExpenseEntry> expenses = const []}) =>
    SundayIncomeForm(
      id: '',
      date: date,
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: const CategoryBlock(denominationBreakdown: {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: men,
      women: women,
      children: children,
      preparedBy: 'a',
      checkedBy: 'b',
      collectedBy: 'c',
      expenseEntries: expenses,
    );

void main() {
  group('the percentage', () {
    test('is the change on the earlier figure, to one decimal place', () {
      expect(_t(1125, 1000).percent, 12.5);
      expect(_t(920, 1000).percent, -8);
      expect(_t(1000, 1000).percent, 0);
      expect(_t(1000, 3).percent, closeTo(33233.3, 0.001));
    });

    test('is written with a sign, and no needless decimals', () {
      expect(_t(1125, 1000).percentText, '+12.5%');
      expect(_t(1100, 1000).percentText, '+10%');
      expect(_t(920, 1000).percentText, '-8%');
      expect(_t(917, 1000).percentText, '-8.3%');
      expect(_t(1000, 1000).percentText, '0%');
    });

    test('has no value without an earlier figure above zero', () {
      for (final trend in [_t(500, 0), _t(0, 0)]) {
        expect(trend.hasBaseline, isFalse);
        expect(trend.percent, isNull);
        expect(trend.band, isNull);
        expect(trend.percentText, 'n/a');
        expect(trend.word, 'No earlier figure');
      }
    });
  });

  group('the remark in words', () {
    final cases = <String, (double, double, TrendBand, String)>{
      'up 25%': (125, 100, TrendBand.strongRise, 'Strong improvement'),
      'up exactly 10%': (110, 100, TrendBand.strongRise, 'Strong improvement'),
      'up 9.9%': (109.9, 100, TrendBand.rise, 'Improved'),
      'up exactly 2%': (102, 100, TrendBand.rise, 'Improved'),
      'up 1.9%': (101.9, 100, TrendBand.steady, 'Steady'),
      'level': (100, 100, TrendBand.steady, 'Steady'),
      'down 1.9%': (98.1, 100, TrendBand.steady, 'Steady'),
      'down exactly 2%': (98, 100, TrendBand.dip, 'Slightly down'),
      'down 9.9%': (90.1, 100, TrendBand.dip, 'Slightly down'),
      'down exactly 10%': (90, 100, TrendBand.fall, 'Needs attention'),
      'down 40%': (60, 100, TrendBand.fall, 'Needs attention'),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final (now, before, band, word) = entry.value;
        expect(_t(now, before).band, band);
        expect(_t(now, before).word, word);
      });
    }

    test('the band follows the rounded percentage that is shown', () {
      // 9.96% shows as +10%, so it must read as a strong improvement.
      expect(_t(109.96, 100).percentText, '+10%');
      expect(_t(109.96, 100).band, TrendBand.strongRise);
    });
  });

  group('the headline sentence', () {
    test('says up, down or level, with the percentage and the remark', () {
      expect(_t(1125, 1000).sentence('Giving', 'last Sunday'),
          'Giving is up 12.5% on last Sunday: Strong improvement.');
      expect(_t(917, 1000).sentence('Giving', 'October 2026'),
          'Giving is down 8.3% on October 2026: Slightly down.');
      expect(_t(1000, 1000).sentence('Giving', '2025'),
          'Giving is level with 2025: Steady.');
    });

    test('says so plainly when there is nothing to compare with', () {
      expect(_t(500, 0).sentence('Giving', 'last Sunday'),
          'Giving: no earlier figure to compare with last Sunday.');
    });

    test('is plain ASCII, so it prints in the PDF font', () {
      for (final trend in [_t(1125, 1000), _t(917, 1000), _t(5, 0)]) {
        expect(trend.sentence('Giving', 'x').runes.where((r) => r > 126), isEmpty);
      }
      for (final band in TrendBand.values) {
        expect(band.word.runes.where((r) => r > 126), isEmpty);
      }
    });
  });

  group('the comparison', () {
    const earlier = PeriodFigures(
        giving: 1000, tithe: 500, averageAttendance: 100, serviceCount: 1);
    const later = PeriodFigures(
        giving: 1100, tithe: 450, averageAttendance: 100, serviceCount: 1);

    test('compares giving, tithe and attendance each on their own', () {
      final c = PeriodComparison.compare(
          current: later, previous: earlier, comparedWith: 'last Sunday');
      expect(c.hasEarlierFigures, isTrue);
      expect(c.giving.word, 'Strong improvement');
      expect(c.tithe.percentText, '-10%');
      expect(c.tithe.word, 'Needs attention');
      expect(c.attendance.word, 'Steady');
      expect(c.headline, 'Giving is up 10% on last Sunday: Strong improvement.');
    });

    test('knows when nothing was recorded before', () {
      const none = PeriodFigures(
          giving: 0, tithe: 0, averageAttendance: 0, serviceCount: 0);
      final c = PeriodComparison.compare(
          current: later, previous: none, comparedWith: 'last Sunday');
      expect(c.hasEarlierFigures, isFalse);
      expect(c.giving.hasBaseline, isFalse);
    });

    test('a week is its giving plus the attendance per service on its forms', () {
      final sunday = DateTime(2026, 11, 22);
      final week = WeekSummary.compute(sunday, [
        _give(sunday, 800),
        _give(sunday, 200, category: GivingCategory.offering),
        _give(DateTime(2026, 11, 15), 999), // another week, ignored
      ]);
      final figures = PeriodFigures.fromWeek(week, [
        _form(sunday, men: 40, women: 55, children: 20), // 115
        _form(sunday, men: 30, women: 40, children: 15), // 85
      ]);
      expect(figures.giving, 1000);
      expect(figures.tithe, 800);
      expect(figures.averageAttendance, 100);
      expect(figures.serviceCount, 2);
      expect(figures.hasData, isTrue);
    });

    test('a month is compared with the month before it', () {
      final records = [
        _give(DateTime(2026, 10, 4), 1000),
        _give(DateTime(2026, 11, 8), 1100),
      ];
      PeriodSummary month(int m) => PeriodSummary.compute(
          start: DateTime(2026, m),
          isYear: false,
          records: records,
          forms: const [],
          valuesByKey: const {});
      final c = PeriodComparison.compare(
          current: PeriodFigures.fromPeriod(month(11)),
          previous: PeriodFigures.fromPeriod(month(10)),
          comparedWith: month(10).label);
      expect(c.comparedWith, 'October 2026');
      expect(c.headline, 'Giving is up 10% on October 2026: Strong improvement.');
    });

    test('an unfinished month is compared with the same days of the last one', () {
      // Today is 23 November: 1-23 November against 1-23 October.
      final end = PeriodSummary.sameStretchEnd(
          start: DateTime(2026, 11),
          previousStart: DateTime(2026, 10),
          now: DateTime(2026, 11, 23, 15));
      expect(end, DateTime(2026, 10, 24)); // exclusive: up to and including the 23rd

      final records = [
        _give(DateTime(2026, 10, 5), 1000),
        _give(DateTime(2026, 10, 25), 9000), // after the 23rd: left out
        _give(DateTime(2026, 11, 9), 1100),
      ];
      final october = PeriodSummary.compute(
          start: DateTime(2026, 10),
          isYear: false,
          records: records,
          forms: const [],
          valuesByKey: const {},
          endExclusive: end);
      expect(october.grandTotal, 1000);
    });

    test('a shorter earlier month never overruns into the current one', () {
      // 31 March against February: stops at 1 March, not into March.
      final end = PeriodSummary.sameStretchEnd(
          start: DateTime(2026, 3),
          previousStart: DateTime(2026, 2),
          now: DateTime(2026, 3, 31));
      expect(end, DateTime(2026, 3));
    });

    test('an unfinished year is compared with the same days of the last year', () {
      final end = PeriodSummary.sameStretchEnd(
          start: DateTime(2026),
          previousStart: DateTime(2025),
          now: DateTime(2026, 11, 23));
      expect(end, DateTime(2025, 11, 24));
    });

    test('a year is compared with the year before it', () {
      final records = [
        _give(DateTime(2025, 6, 1), 4000),
        _give(DateTime(2026, 6, 1), 3600),
      ];
      PeriodSummary year(int y) => PeriodSummary.compute(
          start: DateTime(y),
          isYear: true,
          records: records,
          forms: const [],
          valuesByKey: const {});
      final c = PeriodComparison.compare(
          current: PeriodFigures.fromPeriod(year(2026)),
          previous: PeriodFigures.fromPeriod(year(2025)),
          comparedWith: year(2025).label);
      expect(c.headline, 'Giving is down 10% on 2025: Needs attention.');
    });
  });

  group('on screen', () {
    Future<void> pump(WidgetTester tester, Widget home,
        {required List<GivingRecord> records,
        List<SundayIncomeForm> forms = const []}) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          givingRecordsProvider.overrideWith((ref) => Stream.value(records)),
          incomeFormsProvider.overrideWith((ref) => Stream.value(forms)),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the weekly statement compares with the previous Sunday',
        (tester) async {
      final sunday = sundayOnOrBefore(DateTime.now());
      final before = DateTime(sunday.year, sunday.month, sunday.day - 7);
      await pump(tester, const WeeklyStatementScreen(), records: [
        _give(sunday, 1100),
        _give(before, 1000),
      ]);
      expect(find.textContaining('Compared with the previous Sunday'),
          findsOneWidget);
      expect(find.text(
              'Giving is up 10% on the previous Sunday (${formatDate(before)}): Strong improvement.'),
          findsOneWidget);
      expect(find.text('+10%'), findsWidgets);
      expect(find.text('Strong improvement'), findsWidgets);
    });

    testWidgets('the weekly statement shows expenses and the net amount after the grand total',
        (tester) async {
      final sunday = sundayOnOrBefore(DateTime.now());
      await pump(tester, const WeeklyStatementScreen(), records: [
        _give(sunday, 1000),
      ], forms: [
        _form(sunday, expenses: const [
          ExpenseEntry(description: 'Missions', amount: 250),
        ]),
      ]);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(find.text('Less: Total Expenses'), findsOneWidget);
      expect(find.text('Net Amount'), findsOneWidget);
      expect(find.text('ZMW 250.00'), findsWidgets);
      expect(find.text('ZMW 750.00'), findsOneWidget); // 1000 less 250
      // Expenses now sit under the grand total, not in the bank-deposit list.
      expect(find.text('Total Expenses'), findsNothing);
    });

    testWidgets('the weekly statement has no net amount when no form was saved',
        (tester) async {
      final sunday = sundayOnOrBefore(DateTime.now());
      await pump(tester, const WeeklyStatementScreen(),
          records: [_give(sunday, 1000)]);
      expect(find.text('Net Amount'), findsNothing);
    });

    testWidgets('the weekly statement says so when the earlier Sunday is empty',
        (tester) async {
      final sunday = sundayOnOrBefore(DateTime.now());
      await pump(tester, const WeeklyStatementScreen(),
          records: [_give(sunday, 1100)]);
      expect(find.textContaining('nothing to compare with yet'), findsOneWidget);
      expect(find.text('+10%'), findsNothing);
    });

    testWidgets('the monthly summary compares with last month and notes it is unfinished',
        (tester) async {
      final now = DateTime.now();
      await pump(tester, const PeriodSummaryScreen(), records: [
        _give(DateTime(now.year, now.month, 1), 1100),
        _give(DateTime(now.year, now.month - 1, 5), 1000),
      ]);
      expect(find.textContaining('Compared with the same days of '),
          findsOneWidget);
      expect(find.textContaining('This period is not over yet'), findsOneWidget);
    });

    testWidgets('the monthly summary switches to comparing years', (tester) async {
      final now = DateTime.now();
      await pump(tester, const PeriodSummaryScreen(), records: [
        _give(DateTime(now.year, 1, 2), 900),
        _give(DateTime(now.year - 1, 6, 5), 1000),
      ]);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.text('Compared with the same days of ${now.year - 1}'),
          findsOneWidget);
    });
  });

  test('the summary PDF carries the comparison, in plain ASCII', () async {
    final records = [
      _give(DateTime(2026, 10, 4), 1000),
      _give(DateTime(2026, 11, 8), 1100),
    ];
    PeriodSummary month(int m) => PeriodSummary.compute(
        start: DateTime(2026, m),
        isYear: false,
        records: records,
        forms: const [],
        valuesByKey: const {});
    final comparison = PeriodComparison.compare(
        current: PeriodFigures.fromPeriod(month(11)),
        previous: PeriodFigures.fromPeriod(month(10)),
        comparedWith: month(10).label,
        ongoing: true);
    expect((await buildPeriodSummaryPdf(month(11), comparison: comparison)).isNotEmpty,
        isTrue);
    // And when there is nothing earlier to compare with.
    final none = PeriodComparison.compare(
        current: PeriodFigures.fromPeriod(month(10)),
        previous: PeriodFigures.fromPeriod(month(9)),
        comparedWith: month(9).label);
    expect((await buildPeriodSummaryPdf(month(10), comparison: none)).isNotEmpty,
        isTrue);

    final source =
        File('lib/features/giving/pdf/period_summary_pdf.dart').readAsStringSync();
    expect(source.runes.where((r) => r > 126), isEmpty);
    final model = File('lib/models/trend.dart').readAsStringSync();
    expect(model.runes.where((r) => r > 126), isEmpty);
  });
}
