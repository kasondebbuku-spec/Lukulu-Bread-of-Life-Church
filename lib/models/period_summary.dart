import '../core/utils/week_utils.dart';
import 'giving_record.dart';
import 'sunday_income_form.dart';
import 'week_income_form_totals.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class WeekTotal {
  const WeekTotal(this.sunday, this.total);

  final DateTime sunday;
  final double total;
}

/// Giving, bank-deposit, expense and attendance totals for a month or a year,
/// rolled up from the giving records and Sunday Income Forms inside it.
class PeriodSummary {
  const PeriodSummary({
    required this.start,
    required this.endExclusive,
    required this.isYear,
    required this.categoryTotals,
    required this.otherTotal,
    required this.weeks,
    required this.formTotals,
    required this.totalAttendance,
  });

  final DateTime start;
  final DateTime endExclusive;
  final bool isYear;

  /// One entry per [GivingCategory].
  final Map<GivingCategory, double> categoryTotals;

  /// Records with no category (older entries) -- kept visible so the grand
  /// total can never silently drop money.
  final double otherTotal;

  /// Giving per Sunday, oldest first; only weeks that had giving.
  final List<WeekTotal> weeks;

  final WeekIncomeFormTotals formTotals;
  final int totalAttendance;

  double get grandTotal =>
      categoryTotals.values.fold(0.0, (sum, v) => sum + v) + otherTotal;

  /// The grand total less the expenses on the Sunday income forms in the period.
  double get netAmount => grandTotal - formTotals.totalExpenses;

  int get serviceCount => formTotals.formCount;

  double get averageAttendance =>
      serviceCount == 0 ? 0 : totalAttendance / serviceCount;

  String get label =>
      isYear ? '${start.year}' : '${_monthNames[start.month - 1]} ${start.year}';

  /// e.g. `period-summary-2026-10.pdf` or `period-summary-2026.pdf`.
  String get pdfFilename => isYear
      ? 'period-summary-${start.year}.pdf'
      : 'period-summary-${start.year}-${start.month.toString().padLeft(2, '0')}.pdf';

  static DateTime monthStart(int year, int month) => DateTime(year, month);

  /// Where the previous period should stop so it covers the same stretch as a
  /// period still in progress (1-23 November against 1-23 October), rather
  /// than a part-month being set against a whole one. Never later than the
  /// start of the current period, so a shorter previous month is not overrun.
  static DateTime sameStretchEnd({
    required DateTime start,
    required DateTime previousStart,
    required DateTime now,
  }) {
    final days = DateTime(now.year, now.month, now.day + 1).difference(start).inDays;
    final candidate =
        DateTime(previousStart.year, previousStart.month, previousStart.day + days);
    return candidate.isBefore(start) ? candidate : start;
  }

  factory PeriodSummary.compute({
    required DateTime start,
    required bool isYear,
    required List<GivingRecord> records,
    required List<SundayIncomeForm> forms,
    required Map<String, double> valuesByKey,
    DateTime? endExclusive,
  }) {
    // [endExclusive] cuts the period short; see [sameStretchEnd].
    final end = endExclusive ??
        (isYear ? DateTime(start.year + 1) : DateTime(start.year, start.month + 1));
    bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(end);

    final totals = {for (final c in GivingCategory.values) c: 0.0};
    var other = 0.0;
    final byWeek = <DateTime, double>{};

    for (final r in records) {
      if (r.currency != 'ZMW' || !inRange(r.date)) continue;
      final category = r.category;
      if (category != null) {
        totals[category] = totals[category]! + r.amount;
      } else {
        other += r.amount;
      }
      final sunday = sundayOnOrBefore(r.date);
      byWeek[sunday] = (byWeek[sunday] ?? 0) + r.amount;
    }

    final periodForms = forms.where((f) => inRange(f.date)).toList();
    final weeks = (byWeek.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => WeekTotal(e.key, e.value))
        .toList();

    return PeriodSummary(
      start: start,
      endExclusive: end,
      isYear: isYear,
      categoryTotals: totals,
      otherTotal: other,
      weeks: weeks,
      formTotals: WeekIncomeFormTotals.fromForms(periodForms, valuesByKey),
      totalAttendance: periodForms.fold(0, (sum, f) => sum + f.attendanceTotal),
    );
  }
}
