import '../core/utils/week_utils.dart';
import 'giving_record.dart';

class WeekSummary {
  const WeekSummary({
    required this.sunday,
    required this.titheTotal,
    required this.offeringTotal,
    required this.specialOfferingTotal,
    required this.otherTotal,
    required this.denominationCounts,
  });

  final DateTime sunday;
  final double titheTotal;
  final double offeringTotal;
  final double specialOfferingTotal;

  /// Legacy/uncategorized records dated into this week — kept separate so
  /// the grand total can never silently drop money that lacks a category.
  final double otherTotal;

  /// Merged denomination counts across every cash-count entry this week.
  final Map<String, int> denominationCounts;

  double get grandTotal => titheTotal + offeringTotal + specialOfferingTotal + otherTotal;

  bool get hasDenominationData => denominationCounts.values.any((c) => c > 0);

  factory WeekSummary.compute(DateTime sunday, List<GivingRecord> allRecords) {
    double tithe = 0, offering = 0, special = 0, other = 0;
    final denomCounts = <String, int>{};

    for (final r in allRecords) {
      if (sundayOnOrBefore(r.date) != sunday) continue;

      switch (r.category) {
        case GivingCategory.tithe:
          tithe += r.amount;
        case GivingCategory.offering:
          offering += r.amount;
        case GivingCategory.specialOffering:
          special += r.amount;
        case null:
          other += r.amount;
      }

      r.denominationBreakdown?.forEach((key, count) {
        denomCounts[key] = (denomCounts[key] ?? 0) + count;
      });
    }

    return WeekSummary(
      sunday: sunday,
      titheTotal: tithe,
      offeringTotal: offering,
      specialOfferingTotal: special,
      otherTotal: other,
      denominationCounts: denomCounts,
    );
  }
}
