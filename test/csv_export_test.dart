import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/file_download_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/core/utils/csv.dart';
import 'package:church_cms/features/giving/export/giving_export.dart';
import 'package:church_cms/features/giving/screens/export_screen.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/repositories/repository_providers.dart';

const _values = {'100': 100.0, '10': 10.0, '1': 1.0};

List<String> _lines(String csv) =>
    csv.replaceFirst('﻿', '').trimRight().split('\r\n');

SundayIncomeForm _form(DateTime date, ServiceType service) => SundayIncomeForm(
      id: 'f',
      date: date,
      service: service,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown: c == GivingCategory.tithe ? {'100': 29} : const {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 40,
      women: 55,
      children: 20,
      preparedBy: 'Inambao, Nanzila',
      checkedBy: 'Msiska Isaac',
      collectedBy: 'Mabai Mike',
      natsaveBlock: const CategoryBlock(denominationBreakdown: {'10': 6}),
      expensesReserveBlock: const CategoryBlock(denominationBreakdown: {'1': 3760}),
      expenseEntries: const [ExpenseEntry(description: 'Missions', amount: 3180)],
    );

void main() {
  group('toCsv', () {
    test('starts with a byte-order mark and uses Windows line endings', () {
      final csv = toCsv([
        ['a', 'b']
      ]);
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv.endsWith('\r\n'), isTrue);
    });

    test('quotes commas, quotes and line breaks', () {
      final csv = toCsv([
        ['Hello, world', 'say "hi"', 'two\nlines', 'plain']
      ]);
      expect(_lines(csv).single, '"Hello, world","say ""hi""","two\nlines",plain');
    });

    test('neutralises text a spreadsheet would run as a formula', () {
      final csv = toCsv([
        ['=HYPERLINK("http://x")', '+1', '-1+2', '@SUM(A1)', 'safe=ok']
      ]);
      final cells = _lines(csv).single;
      expect(cells, contains("\"'=HYPERLINK(\"\"http://x\"\")\""));
      expect(cells, contains("'+1"));
      expect(cells, contains("'-1+2"));
      expect(cells, contains("'@SUM(A1)"));
      expect(cells, contains('safe=ok'));
    });

    test('numbers stay numbers (including negatives), booleans read Yes/No', () {
      final csv = toCsv([
        [2900.0, 12.5, -580.0, 7, true, false, null]
      ]);
      expect(_lines(csv).single, '2900,12.50,-580,7,Yes,No,');
    });
  });

  group('exports', () {
    test('giving CSV is oldest first with a clear header', () {
      final csv = givingCsv([
        GivingRecord(
            id: 'b',
            memberName: 'Tithe, Evening',
            amount: 50.5,
            date: DateTime(2026, 10, 11),
            category: GivingCategory.tithe),
        GivingRecord(
            id: 'a',
            memberName: 'Old gift',
            amount: 10,
            currency: 'USD',
            date: DateTime(2026, 1, 4),
            memberUserId: 'u1'),
      ]);
      final lines = _lines(csv);
      expect(lines.first,
          'Date,Category,Description,Amount,Currency,Linked to a member account,Reference');
      expect(lines[1], '2026-01-04,Uncategorized,Old gift,10,USD,Yes,a');
      expect(lines[2], '2026-10-11,Tithe,"Tithe, Evening",50.50,ZMW,No,b');
    });

    test('forms CSV carries the totals the paper form calculates', () {
      final csv = incomeFormsCsv([
        _form(DateTime(2026, 10, 11), ServiceType.evening),
        _form(DateTime(2026, 10, 4), ServiceType.morning),
      ], _values);
      final lines = _lines(csv);
      expect(lines.length, 3);
      final header = lines.first.split(',');
      final first = lines[1];
      expect(first.startsWith('2026-10-04,Morning,'), isTrue); // oldest first
      expect(lines[2].startsWith('2026-10-11,Evening,'), isTrue);

      String col(String name) {
        // Values here contain a quoted comma only in the names, which come last.
        final cells = first.split(',');
        return cells[header.indexOf(name)];
      }

      expect(col('Tithe'), '2900');
      expect(col('Grand total'), '2900');
      expect(col('20% of tithe (remittance)'), '580');
      expect(col('Natsave deposit'), '60');
      expect(col('Total collection'), '640');
      expect(col('Total expenses'), '3180');
      expect(col('Reserve variance'), '0');
      expect(col('Reconciled'), 'Yes');
      expect(col('Attendance'), '115');
      expect(first, contains('"Inambao, Nanzila"'));
    });
  });

  group('export screen', () {
    final giving = [
      GivingRecord(
          id: '1', memberName: 'A', amount: 10, date: DateTime(2026, 3, 1)),
      GivingRecord(
          id: '2', memberName: 'B', amount: 20, date: DateTime(2025, 3, 1)),
    ];
    final forms = [_form(DateTime(2026, 10, 4), ServiceType.morning)];

    Future<List<List<String>>> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final downloads = <List<String>>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          givingRecordsProvider.overrideWith((ref) => Stream.value(giving)),
          incomeFormsProvider.overrideWith((ref) => Stream.value(forms)),
          fileDownloaderProvider
              .overrideWithValue((name, content) => downloads.add([name, content])),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const ExportScreen()),
      ));
      await tester.pumpAndSettle();
      return downloads;
    }

    testWidgets('downloads the chosen dataset with a named file', (tester) async {
      final downloads = await pump(tester);
      expect(find.textContaining('2 record(s)'), findsOneWidget);
      expect(find.textContaining('1 form(s)'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'CSV').first);
      await tester.pump();
      expect(downloads.single.first, 'giving-all.csv');
      expect(downloads.single.last, contains('Reference'));
    });

    testWidgets('filtering by year limits the rows and names the file', (tester) async {
      final downloads = await pump(tester);
      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('1 record(s)'), findsOneWidget);
      expect(find.textContaining('0 form(s)'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'CSV').first);
      await tester.pump();
      expect(downloads.single.first, 'giving-2025.csv');
      expect(downloads.single.last.contains(',B,'), isTrue);
      expect(downloads.single.last.contains(',A,'), isFalse);
    });
  });
}
