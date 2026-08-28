import '../core/utils/week_utils.dart';
import 'giving_record.dart';

class WeekSummary {
  const WeekSummary({
    required this.sunday,
    required this.categoryTotals,
    required this.otherTotal,
    required this.denominationCounts,
  });

  final DateTime sunday;

  /// One entry per GivingCategory value.
  final Map<GivingCategory, double> categoryTotals;

  /// Legacy/uncategorized records dated into this week — kept separate so
  /// the grand total can never silently drop money that lacks a category.
  final double otherTotal;

  /// Merged denomination counts across every cash-count entry this week.
  final Map<String, int> denominationCounts;

  double get grandTotal =>
      categoryTotals.values.fold(0.0, (sum, v) => sum + v) + otherTotal;

  bool get hasDenominationData => denominationCounts.values.any((c) => c > 0);

  factory WeekSummary.compute(DateTime sunday, List<GivingRecord> allRecords) {
    final totals = {for (final c in GivingCategory.values) c: 0.0};
    double other = 0;
    final denomCounts = <String, int>{};

    for (final r in allRecords) {
      if (sundayOnOrBefore(r.date) != sunday) continue;

      final category = r.category;
      if (category != null) {
        totals[category] = totals[category]! + r.amount;
      } else {
        other += r.amount;
      }

      r.denominationBreakdown?.forEach((key, count) {
        denomCounts[key] = (denomCounts[key] ?? 0) + count;
      });
    }

    return WeekSummary(
      sunday: sunday,
      categoryTotals: totals,
      otherTotal: other,
      denominationCounts: denomCounts,
    );
  }
}
