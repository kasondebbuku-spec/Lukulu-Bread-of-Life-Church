import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/pdf/member_statement_pdf.dart';
import 'package:church_cms/features/giving/screens/my_giving_screen.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/member_giving_statement.dart';
import 'package:church_cms/repositories/repository_providers.dart';

GivingRecord _r(String id, DateTime date, double amount,
        {GivingCategory? category = GivingCategory.tithe, String currency = 'ZMW'}) =>
    GivingRecord(
        id: id,
        memberName: 'm',
        amount: amount,
        currency: currency,
        date: date,
        category: category);

void main() {
  final records = [
    _r('a', DateTime(2026, 1, 4), 100),
    _r('b', DateTime(2026, 1, 25), 50, category: GivingCategory.offering),
    _r('c', DateTime(2026, 3, 1), 200),
    _r('d', DateTime(2026, 3, 8), 25, category: null),
    _r('e', DateTime(2026, 5, 3), 30, currency: 'USD'),
    _r('f', DateTime(2025, 12, 28), 999), // other year
  ];

  MemberGivingStatement stmt([int year = 2026]) =>
      MemberGivingStatement.compute(memberName: 'Daniel Thomas', year: year, records: records);

  test('totals, months and categories are per currency, ZMW first', () {
    final s = stmt();
    expect(s.currencies.map((c) => c.currency), ['ZMW', 'USD']);

    final zmw = s.currencies.first;
    expect(zmw.total, 375);
    expect(zmw.byMonth[0], 150); // January
    expect(zmw.byMonth[2], 225); // March
    expect(zmw.byMonth[1], 0);
    expect(zmw.byCategory[GivingCategory.tithe], 300);
    expect(zmw.byCategory[GivingCategory.offering], 50);
    expect(zmw.uncategorized, 25);
    expect(zmw.records.map((r) => r.id), ['a', 'b', 'c', 'd']); // oldest first

    expect(s.currencies.last.total, 30);
  });

  test('other years are excluded and years are listed newest first', () {
    expect(stmt(2025).currencies.single.total, 999);
    expect(MemberGivingStatement.yearsWithGiving(records), [2026, 2025]);
    expect(stmt(2024).isEmpty, isTrue);
    expect(stmt().pdfFilename, 'giving-statement-2026.pdf');
  });

  test('the statement PDF renders (also for an empty year) using plain ASCII', () async {
    final when = DateTime(2026, 10, 9);
    expect((await buildMemberStatementPdf(stmt(), generatedOn: when)).isNotEmpty, isTrue);
    expect((await buildMemberStatementPdf(stmt(2024), generatedOn: when)).isNotEmpty, isTrue);

    final source =
        File('lib/features/giving/pdf/member_statement_pdf.dart').readAsStringSync();
    expect(source.runes.where((r) => r > 126), isEmpty);
  });

  Future<void> pumpScreen(WidgetTester tester, List<GivingRecord> data) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [myGivingProvider.overrideWith((ref) => Stream.value(data))],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const MyGivingScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('My Giving offers a yearly statement for years that have giving',
      (tester) async {
    await pumpScreen(tester, records);
    expect(find.text('Yearly statement'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget); // newest year preselected
  });

  testWidgets('no statement card when there is no giving', (tester) async {
    await pumpScreen(tester, const []);
    expect(find.text('Yearly statement'), findsNothing);
  });
}
