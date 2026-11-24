import 'dart:typed_data';

import '../../../models/expense_entry.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../zmw_denominations.dart';
import 'xlsx_reader.dart';

/// Raised when a file opens but is not the church's Sunday income sheet.
class IncomeSheetFormatException implements Exception {
  const IncomeSheetFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What was read from the Sunday income sheet (the "Income Analysis Breakdown
/// (Form 2)" the Finance team fills in). It is only ever a draft: it fills in the
/// form for a person to check and save, it is never saved by itself.
class IncomeSheetImport {
  const IncomeSheetImport({
    required this.counts,
    required this.expenses,
    required this.warnings,
    this.date,
    this.service,
    this.preparedBy,
    this.checkedBy,
    this.collectedBy,
    this.sheetOverallTotal,
  });

  /// How many of each note and coin, per category found on the sheet
  /// (keyed like [zmwDenominations]).
  final Map<GivingCategory, Map<String, int>> counts;
  final List<ExpenseEntry> expenses;

  /// Things worth a second look: odd values, totals that do not agree.
  final List<String> warnings;

  final DateTime? date;
  final ServiceType? service;
  final String? preparedBy;
  final String? checkedBy;
  final String? collectedBy;

  /// The OVERALL sub-total the sheet itself calculated, when it has one.
  final double? sheetOverallTotal;

  /// All the cash the sheet's category tables add up to, in Kwacha.
  double get countedTotal => counts.values.fold(
      0.0,
      (sum, byNote) =>
          sum +
          byNote.entries.fold(0.0, (s, e) => s + _valueOfKey(e.key) * e.value));
}

double _valueOfKey(String key) =>
    zmwDenominations.firstWhere((d) => d.key == key).value;

const _categoryHeadings = <String, GivingCategory>{
  'OFFERING': GivingCategory.offering,
  'SEED': GivingCategory.seed,
  'THANKSGIVING': GivingCategory.thanksgiving,
  'TITHE': GivingCategory.tithe,
  'PLEDGES': GivingCategory.pledge,
  'PLEDGE': GivingCategory.pledge,
};

/// Letters only, upper case: `"   THANKS GIVING "` -> `THANKSGIVING`.
String _norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

String? _denominationKeyFor(double value) {
  for (final d in zmwDenominations) {
    if ((d.value - value).abs() < 0.0001) return d.key;
  }
  return null;
}

String _titleCase(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String _money(double v) =>
    v == v.roundToDouble() ? 'K${v.toStringAsFixed(0)}' : 'K${v.toStringAsFixed(2)}';

/// Reads a Sunday income sheet (`.xlsx`).
///
/// It finds each table by its heading (Offering, Seed, Thanks Giving, Tithe,
/// Pledges) rather than by fixed cell addresses, so it still works if the sheet
/// is nudged along a column or row. The sheet's own totals and the 20% line are
/// ignored: the app works those out itself.
///
/// Throws [IncomeSheetFormatException] if the file is not an income sheet.
IncomeSheetImport parseIncomeSheet(Uint8List bytes) {
  final SheetData sheet;
  try {
    sheet = readFirstSheet(bytes);
  } on FormatException {
    throw const IncomeSheetFormatException(
        'That file could not be read. Please choose the Sunday income sheet saved as an Excel .xlsx file.');
  }

  final warnings = <String>[];
  final counts = <GivingCategory, Map<String, int>>{};
  double? overall;

  // The row of column headings under a table heading holds NOTE VALUE; the
  // counts sit in the next column.
  int? valueColumnUnder(int headingRow, int headingCol) {
    for (var r = headingRow + 1; r <= headingRow + 3; r++) {
      for (var c = headingCol; c <= headingCol + 4; c++) {
        final t = sheet.text(r, c);
        if (t != null && _norm(t) == 'NOTEVALUE') return c;
      }
    }
    return null;
  }

  int? headerRowUnder(int headingRow, int headingCol) {
    for (var r = headingRow + 1; r <= headingRow + 3; r++) {
      for (var c = headingCol; c <= headingCol + 4; c++) {
        final t = sheet.text(r, c);
        if (t != null && _norm(t) == 'NOTEVALUE') return r;
      }
    }
    return null;
  }

  for (final h in sheet.textCells) {
    final n = _norm(h.text);

    if (_categoryHeadings.containsKey(n)) {
      final category = _categoryHeadings[n]!;
      final valueCol = valueColumnUnder(h.row, h.col);
      final headerRow = headerRowUnder(h.row, h.col);
      if (valueCol == null || headerRow == null) {
        warnings.add('Could not find the note values under "${h.text.trim()}".');
        continue;
      }
      final byNote = <String, int>{};
      for (var r = headerRow + 1; r <= headerRow + 16; r++) {
        final value = sheet.number(r, valueCol);
        if (value == null) break; // the SUB-TOTAL row ends the table
        final key = _denominationKeyFor(value);
        final raw = sheet.number(r, valueCol + 1);
        if (key == null) {
          if (raw != null && raw != 0) {
            warnings.add('Skipped a note value that is not a Kwacha note or coin: $value.');
          }
          continue;
        }
        if (raw == null || raw == 0) continue;
        final count = raw.round();
        if ((raw - count).abs() > 0.001 || count < 0) {
          warnings.add('${category.label}: the count for ${_money(value)} '
              '($raw) is not a whole number, so it was left out.');
          continue;
        }
        byNote[key] = (byNote[key] ?? 0) + count;
      }
      // A table that appears twice is added together rather than overwritten.
      final merged = counts.putIfAbsent(category, () => <String, int>{});
      byNote.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    } else if (n == 'OVERALL') {
      final valueCol = valueColumnUnder(h.row, h.col);
      final headerRow = headerRowUnder(h.row, h.col);
      if (valueCol == null || headerRow == null) continue;
      for (var r = headerRow + 1; r <= headerRow + 16; r++) {
        // Find the SUB-TOTAL label anywhere across this block's columns.
        final isSubTotal = [
          for (var c = h.col; c <= valueCol + 2; c++) sheet.text(r, c),
        ].any((t) => t != null && _norm(t).contains('SUBTOTAL'));
        if (isSubTotal) {
          overall = sheet.number(r, valueCol + 2);
          break;
        }
      }
    }
  }

  if (counts.isEmpty) {
    throw const IncomeSheetFormatException(
        'This does not look like the Sunday income sheet: no Offering, Tithe, '
        'Seed, Thanks Giving or Pledges table was found.');
  }

  // Date and service from the heading line ("Date: 22.11.2026 Service: MORNING").
  DateTime? date;
  ServiceType? service;
  for (final t in sheet.textCells) {
    final d = RegExp(
            r'DATE\s*[:\-]?\s*(\d{1,2})\s*[./\-]\s*(\d{1,2})\s*[./\-]\s*(\d{2,4})',
            caseSensitive: false)
        .firstMatch(t.text);
    if (d != null && date == null) {
      var year = int.parse(d.group(3)!);
      if (year < 100) year += 2000;
      final month = int.parse(d.group(2)!);
      final day = int.parse(d.group(1)!);
      final candidate = DateTime(year, month, day);
      if (candidate.month == month && candidate.day == day) {
        date = candidate;
      } else {
        warnings.add('The date on the sheet (${d.group(0)}) is not a real date.');
      }
    }
    final s = RegExp(r'SERVICE\s*[:\-]?\s*([A-Za-z]+)', caseSensitive: false)
        .firstMatch(t.text);
    if (s != null && service == null) {
      final w = s.group(1)!.toUpperCase();
      if (w.startsWith('MORN')) service = ServiceType.morning;
      if (w.startsWith('EVEN')) service = ServiceType.evening;
    }
  }

  // "PREPARED BY: A  CHECKED BY: B  COLLECTED BY: C", all in one cell.
  String? prepared, checked, collected;
  for (final t in sheet.textCells) {
    final m = RegExp(
            r'PREPARED\s*BY\s*:?\s*(.*?)\s*CHECKED\s*BY\s*:?\s*(.*?)\s*COLLECTED\s*BY\s*:?\s*(.*)$',
            caseSensitive: false,
            dotAll: true)
        .firstMatch(t.text);
    if (m != null) {
      String? name(int i) => m.group(i)!.trim().isEmpty ? null : _titleCase(m.group(i)!);
      prepared = name(1);
      checked = name(2);
      collected = name(3);
      break;
    }
  }

  // Expenses: a heading "Expenses", descriptions beneath it, amounts in the
  // next column. The sheet's own SUM row and "Balance" are not expenses.
  final expenses = <ExpenseEntry>[];
  for (final h in sheet.textCells) {
    if (_norm(h.text) != 'EXPENSES') continue;
    for (var r = h.row + 1; r <= h.row + 25; r++) {
      final label = sheet.text(r, h.col);
      if (label != null && _norm(label).startsWith('BALANCE')) break;
      final cell = sheet.cell(r, h.col + 1);
      final amount = cell?.number;
      if (cell == null || cell.isFormula || amount == null || amount <= 0) continue;
      expenses.add(ExpenseEntry(
          description: (label ?? '').trim().isEmpty ? 'Expense' : label!.trim(),
          amount: amount));
    }
    break;
  }

  final result = IncomeSheetImport(
    counts: counts,
    expenses: expenses,
    warnings: warnings,
    date: date,
    service: service,
    preparedBy: prepared,
    checkedBy: checked,
    collectedBy: collected,
    sheetOverallTotal: overall,
  );

  // The sheet adds its own OVERALL table. If that disagrees with what its
  // category tables add up to, something was mistyped: say so.
  if (overall != null && (overall - result.countedTotal).abs() > 0.01) {
    warnings.add('The sheet\'s own OVERALL total (${_money(overall)}) does not '
        'match the tables above it (${_money(result.countedTotal)}). '
        'Please check the counts.');
  }
  return result;
}
