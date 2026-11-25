import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/audit_actor_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/file_upload_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/import/income_sheet_parser.dart';
import 'package:church_cms/features/giving/import/xlsx_reader.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';
import 'package:church_cms/models/audit_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/repositories/income_form_repository.dart';
import 'package:church_cms/repositories/repository_providers.dart';

// ---------------------------------------------------------------------------
// Builds a real .xlsx (a zip of XML, written the way Excel writes it: text in
// a shared-strings table, formulas next to their calculated values).
// ---------------------------------------------------------------------------

/// A cell value is a [String], a [num], or a [Formula] holding its answer.
class Formula {
  const Formula(this.text, this.value);
  final String text;
  final Object value;
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

Uint8List buildXlsx(Map<String, Object> cells) {
  final strings = <String>[];
  int indexOf(String s) {
    final i = strings.indexOf(s);
    if (i >= 0) return i;
    strings.add(s);
    return strings.length - 1;
  }

  final byRow = <int, List<MapEntry<String, Object>>>{};
  for (final e in cells.entries) {
    final row = int.parse(RegExp(r'\d+').firstMatch(e.key)!.group(0)!);
    byRow.putIfAbsent(row, () => []).add(e);
  }
  final rows = byRow.keys.toList()..sort();

  String cellXml(String ref, Object v) {
    if (v is Formula) {
      final isText = v.value is String;
      return '<c r="$ref"${isText ? ' t="str"' : ''}><f>${_esc(v.text)}</f>'
          '<v>${_esc('${v.value}')}</v></c>';
    }
    if (v is String) return '<c r="$ref" t="s"><v>${indexOf(v)}</v></c>';
    return '<c r="$ref"><v>$v</v></c>';
  }

  final sheetData = StringBuffer();
  for (final r in rows) {
    sheetData.write('<row r="$r">');
    for (final e in byRow[r]!) {
      sheetData.write(cellXml(e.key, e.value));
    }
    sheetData.write('</row>');
  }

  final sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>$sheetData</sheetData></worksheet>';
  final shared = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${strings.map((s) => '<si><t xml:space="preserve">${_esc(s)}</t></si>').join()}</sst>';

  final archive = Archive()
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet))
    ..addFile(ArchiveFile.string('xl/sharedStrings.xml', shared));
  return ZipEncoder().encodeBytes(archive);
}

const _notes = [500, 200, 100, 50, 20, 10, 5, 2, 1, 0.5];

/// The church's sheet laid out as the real one is: Offering / Seed / Thanks
/// Giving across the top, Tithe / Pledges / Overall beneath, expenses under that.
/// [dr] and [dc] shift the whole thing (to prove it is found by headings).
Map<String, Object> incomeSheet({
  Map<num, int> offering = const {},
  Map<num, int> seed = const {},
  Map<num, int> thanks = const {},
  Map<num, int> tithe = const {},
  Map<num, int> pledges = const {},
  String header = 'P.                  Date: 22.11.2026         Service: MORNING        Day: SUNDAY',
  String names =
      'PREPARED BY: MWABA MAUREEN CHECKED BY:  ELDER KABWE PETER  COLLECTED BY: MABAI MIKE ',
  List<(String, num)> expenses = const [],
  double? overallOverride,
  int dr = 0,
  int dc = 0,
}) {
  final out = <String, Object>{};
  String ref(String col, int row) {
    final c = col.codeUnitAt(0) - 64 + dc;
    return '${String.fromCharCode(64 + c)}${row + dr}';
  }

  void put(String col, int row, Object v) => out[ref(col, row)] = v;

  void table(String heading, String sn, String val, String cnt, String amt,
      int top, Map<num, int> counts) {
    put(sn, top, heading);
    put(sn, top + 1, 'S/N');
    put(val, top + 1, 'NOTE VALUE ');
    put(cnt, top + 1, 'NOTE COUNT');
    put(amt, top + 1, 'AMOUNT (K)');
    for (var i = 0; i < _notes.length; i++) {
      final r = top + 2 + i;
      put(sn, r, '${i + 1}');
      put(val, r, _notes[i]);
      final n = counts[_notes[i]];
      if (n != null) put(cnt, r, n);
      put(amt, r, Formula('+$val$r*$cnt$r', _notes[i] * (n ?? 0)));
    }
    put(sn, top + 12, 'SUB-TOTAL ');
  }

  put('B', 1, 'BREAD OF LIFE CHURCH INTERNATIONAL - LUKULU');
  put('B', 3, header);
  table('                        OFFERING', 'B', 'C', 'D', 'E', 4, offering);
  table('                          SEED', 'G', 'H', 'I', 'J', 4, seed);
  table('THANKS GIVING', 'L', 'M', 'N', 'O', 4, thanks);
  table('                            TITHE', 'B', 'C', 'D', 'E', 18, tithe);
  table('                      PLEDGES', 'G', 'H', 'I', 'J', 18, pledges);
  table('                          OVERALL', 'L', 'M', 'N', 'O', 18, const {});
  final total = [offering, seed, thanks, tithe, pledges].fold<double>(
      0, (s, m) => s + m.entries.fold(0.0, (t, e) => t + e.key * e.value));
  put('O', 30, Formula('SUM(O20:O29)', overallOverride ?? total));
  put('G', 31, names);

  put('C', 33, 'Expenses ');
  for (var i = 0; i < expenses.length; i++) {
    put('C', 34 + i, expenses[i].$1);
    put('D', 34 + i, expenses[i].$2);
  }
  put('D', 39,
      Formula('SUM(D34:D38)', expenses.fold<double>(0, (s, e) => s + e.$2)));
  put('C', 40, 'Balance');
  return out;
}

/// The Sunday the deacon sent: offering K1,479, tithe K800.
Uint8List deaconsSheet() => buildXlsx(incomeSheet(
      offering: {100: 2, 50: 10, 20: 20, 10: 37, 2: 2, 1: 5},
      tithe: {100: 8},
    ));

// ---------------------------------------------------------------------------

class _FakeRepository implements IncomeFormRepository {
  final saved = <SundayIncomeForm>[];

  @override
  Future<String> saveAndCascade(SundayIncomeForm form,
      Map<String, double> valuesByKey,
      {required AuditActor actor}) async {
    saved.add(form);
    return 'new-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('reading the spreadsheet file', () {
    test('finds cells, text and numbers, and knows which are formulas', () {
      final sheet = readFirstSheet(buildXlsx({
        'A1': 'Hello',
        'B2': 42,
        'C3': const Formula('1+1', 2),
        'AA4': 'Far column',
      }));
      expect(sheet.text(1, 1), 'Hello');
      expect(sheet.number(2, 2), 42);
      expect(sheet.cell(3, 3)!.isFormula, isTrue);
      expect(sheet.number(3, 3), 2);
      expect(sheet.text(4, 27), 'Far column'); // AA is column 27
      expect(sheet.cell(9, 9), isNull);
    });

    test('rejects something that is not an Excel file', () {
      expect(() => readFirstSheet(Uint8List.fromList([1, 2, 3, 4])),
          throwsFormatException);
    });
  });

  group('reading the Sunday income sheet', () {
    test("reads the deacon's sheet: date, service, names, counts", () {
      final r = parseIncomeSheet(deaconsSheet());
      expect(r.date, DateTime(2026, 11, 22));
      expect(r.service, ServiceType.morning);
      // Names are title-cased from the sheet's capitals.
      expect(r.preparedBy, 'Mwaba Maureen');
      expect(r.checkedBy, 'Elder Kabwe Peter');
      expect(r.collectedBy, 'Mabai Mike');

      expect(r.counts[GivingCategory.offering],
          {'100': 2, '50': 10, '20': 20, '10': 37, '2': 2, '1': 5});
      expect(r.counts[GivingCategory.tithe], {'100': 8});
      expect(r.counts[GivingCategory.seed], isEmpty);

      // 1479 offering + 800 tithe, and the sheet's own OVERALL agrees.
      expect(r.countedTotal, 2279);
      expect(r.sheetOverallTotal, 2279);
      expect(r.warnings, isEmpty);
      expect(r.expenses, isEmpty);
    });

    test('reads every category, adding the same note up per table', () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {500: 1},
        seed: {200: 2},
        thanks: {100: 3},
        tithe: {50: 4},
        pledges: {20: 5, 0.5: 4},
      )));
      expect(r.counts[GivingCategory.offering], {'500': 1});
      expect(r.counts[GivingCategory.seed], {'200': 2});
      expect(r.counts[GivingCategory.thanksgiving], {'100': 3});
      expect(r.counts[GivingCategory.tithe], {'50': 4});
      expect(r.counts[GivingCategory.pledge], {'20': 5, '0.5': 4});
      expect(r.countedTotal, 500 + 400 + 300 + 200 + 100 + 2);
    });

    test('finds the tables by their headings, so a shifted sheet still reads',
        () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {100: 2},
        tithe: {100: 8},
        dr: 3,
        dc: 1,
      )));
      expect(r.counts[GivingCategory.offering], {'100': 2});
      expect(r.counts[GivingCategory.tithe], {'100': 8});
      expect(r.countedTotal, 1000);
    });

    test('reads expenses with their descriptions and ignores the sheet\'s own sum',
        () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {100: 10},
        expenses: [('Missions', 300), ('Tissue', 80)],
      )));
      expect(r.expenses.map((e) => e.description), ['Missions', 'Tissue']);
      expect(r.expenses.map((e) => e.amount), [300, 80]);
      // The sum row (380) and "Balance" are not expenses.
      expect(r.expenses, hasLength(2));
    });

    test('an expense typed without a description is still read', () {
      final cells = incomeSheet(offering: {100: 1}, expenses: [('', 50)]);
      cells.remove('C34'); // an empty description cell is simply absent
      final r = parseIncomeSheet(buildXlsx(cells));
      expect(r.expenses.single.description, 'Expense');
      expect(r.expenses.single.amount, 50);
    });

    test('reads an evening service and a short date', () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {100: 1},
        header: 'Date: 15/11/26   Service: EVENING   Day: SUNDAY',
      )));
      expect(r.date, DateTime(2026, 11, 15));
      expect(r.service, ServiceType.evening);
    });

    test('says so when the sheet\'s own total does not match its tables', () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {100: 10},
        overallOverride: 1100, // the sheet claims 1,100 but the tables give 1,000
      )));
      expect(r.warnings.single, contains('OVERALL total (K1100)'));
      expect(r.warnings.single, contains('(K1000)'));
    });

    test('leaves out a count that is not a whole number, and says so', () {
      final r = parseIncomeSheet(buildXlsx(incomeSheet(
        offering: {100: 2},
        tithe: {50: 1},
      )..['D8'] = 2.5));
      // D8 is the offering K100 count.
      expect(r.counts[GivingCategory.offering] ?? const {}, isEmpty);
      expect(r.warnings.any((w) => w.contains('not a whole number')), isTrue);
    });

    test('a file that is not the income sheet is refused with a clear message',
        () {
      expect(
          () => parseIncomeSheet(buildXlsx({'A1': 'Shopping list', 'A2': 'Bread'})),
          throwsA(isA<IncomeSheetFormatException>().having((e) => e.message,
              'message', contains('does not look like the Sunday income sheet'))));
    });

    test('a file that is not Excel at all is refused with a clear message', () {
      expect(() => parseIncomeSheet(Uint8List.fromList([9, 9, 9])),
          throwsA(isA<IncomeSheetFormatException>().having(
              (e) => e.message, 'message', contains('could not be read'))));
    });
  });

  group('importing into the form', () {
    Future<_FakeRepository> pump(WidgetTester tester,
        {Future<Uint8List?> Function()? picker,
        SundayIncomeForm? editing,
        bool signedIn = true}) async {
      tester.view.physicalSize = const Size(900, 14000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          userRoleProvider.overrideWith(
              (ref) => Stream.value(const UserAccess({UserRole.finance}))),
          displayNameProvider.overrideWithValue('Mary Banda'),
          auditActorProvider.overrideWithValue(
              signedIn ? const AuditActor(uid: 'u1', name: 'Mary Banda') : null),
          incomeFormRepositoryProvider.overrideWithValue(repo),
          spreadsheetPickerProvider
              .overrideWithValue(picker ?? () async => deaconsSheet()),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: SundayIncomeFormScreen(initialForm: editing)),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> tapImport(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('import-sheet')));
      await tester.pumpAndSettle();
    }

    testWidgets("fills the form from the deacon's sheet", (tester) async {
      await pump(tester);
      await tapImport(tester);

      // What was read, in words, for the person to check.
      expect(find.byKey(const Key('import-notes')), findsOneWidget);
      expect(
          find.textContaining(
              'Read from the sheet: Tithe ZMW 800.00, Offering ZMW 1479.00. Overall cash ZMW 2279.00.'),
          findsOneWidget);
      expect(find.text('No expenses were found on the sheet.'), findsOneWidget);

      // The form itself.
      expect(find.text('Service Sunday: Nov 22, 2026'), findsOneWidget);
      expect(find.text('Morning'), findsWidgets);
      final checkedBy = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Checked By'));
      expect(checkedBy.controller!.text, 'Elder Kabwe Peter');
      final preparedBy = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Prepared By'));
      expect(preparedBy.controller!.text, 'Mwaba Maureen');

      // The figures flow through to the totals the same as typed ones.
      expect(find.text('ZMW 2279.00'), findsWidgets); // grand total and overall
      expect(find.text('Tithe of Tithes (20% of tithe): ZMW 160.00'), findsOneWidget);
      expect(find.text('Natsave Deposit: ZMW 2119.00'), findsOneWidget);

      // Attendance is not on the sheet, so the person is told to add it.
      expect(find.text('Not on the sheet, so please fill in: Men, Women, Children.'),
          findsOneWidget);
    });

    testWidgets('then saves exactly what the sheet said', (tester) async {
      final repo = await pump(tester);
      await tapImport(tester);
      for (final (label, value) in [
        ('Men', '40'),
        ('Women', '55'),
        ('Children', '20'),
      ]) {
        await tester.enterText(find.widgetWithText(TextFormField, label), value);
      }
      await tester.tap(find.text('Save Form'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final form = repo.saved.single;
      expect(form.date, DateTime(2026, 11, 22));
      expect(form.service, ServiceType.morning);
      expect(form.categoryBlocks[GivingCategory.tithe]!.denominationBreakdown['100'], 8);
      expect(form.categoryBlocks[GivingCategory.offering]!.denominationBreakdown['10'], 37);
      expect(form.checkedBy, 'Elder Kabwe Peter');
      expect(form.enteredBy, 'Mary Banda'); // who typed it in, not who the sheet names
      expect(find.byType(IncomeFormDetailScreen), findsOneWidget);
    });

    testWidgets('does nothing if the chooser is closed without a file',
        (tester) async {
      await pump(tester, picker: () async => null);
      await tapImport(tester);
      expect(find.byKey(const Key('import-notes')), findsNothing);
      expect(find.text('ZMW 2279.00'), findsNothing);
    });

    testWidgets('a wrong file gives a plain message and changes nothing',
        (tester) async {
      await pump(tester,
          picker: () async => buildXlsx({'A1': 'Shopping list'}));
      await tapImport(tester);
      expect(find.textContaining('does not look like the Sunday income sheet'),
          findsOneWidget);
      expect(find.byKey(const Key('import-notes')), findsNothing);
    });

    testWidgets('asks before replacing what was already typed', (tester) async {
      await pump(tester);
      // Type a tithe note count first (field 0 is the tithe K500).
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.pumpAndSettle();

      await tapImport(tester);
      expect(find.text('Replace what you have entered?'), findsOneWidget);

      await tester.tap(find.text('Keep mine'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-notes')), findsNothing);
      expect(find.text('ZMW 1500.00'), findsWidgets); // the 3 x K500 still there

      await tapImport(tester);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-notes')), findsOneWidget);
      expect(find.text('ZMW 2279.00'), findsWidgets);
    });

    testWidgets('the notes can be dismissed', (tester) async {
      await pump(tester);
      await tapImport(tester);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-notes')), findsNothing);
      // The figures stay.
      expect(find.text('ZMW 2279.00'), findsWidgets);
    });

    testWidgets('a date that is not a Sunday is moved back to the Sunday before',
        (tester) async {
      await pump(tester,
          picker: () async => buildXlsx(incomeSheet(
                offering: {100: 1},
                header: 'Date: 24.11.2026   Service: MORNING',
              )));
      await tapImport(tester);
      expect(find.text('Service Sunday: Nov 22, 2026'), findsOneWidget);
      expect(find.textContaining('is not a Sunday'), findsOneWidget);
    });

    testWidgets('expenses on the sheet become expense rows', (tester) async {
      await pump(tester,
          picker: () async => buildXlsx(incomeSheet(
                offering: {100: 10},
                expenses: [('Missions', 300), ('Tissue', 80)],
              )));
      await tapImport(tester);
      expect(find.textContaining('2 expenses read, total ZMW 380.00.'), findsOneWidget);
      expect(find.text('Less: Total Expenses'), findsWidgets);
      expect(find.text('ZMW 380.00'), findsWidgets);
    });

    testWidgets('is not offered when editing a saved form', (tester) async {
      final saved = SundayIncomeForm(
        id: 'abc',
        date: DateTime(2026, 11, 22),
        service: ServiceType.morning,
        categoryBlocks: {
          for (final c in GivingCategory.values)
            c: const CategoryBlock(denominationBreakdown: {}),
        },
        forexEntries: const [],
        chequeEntries: const [],
        men: 1,
        women: 1,
        children: 1,
        preparedBy: 'a',
        checkedBy: 'b',
        collectedBy: 'c',
      );
      await pump(tester, editing: saved);
      expect(find.byKey(const Key('import-sheet')), findsNothing);
    });
  });
}
