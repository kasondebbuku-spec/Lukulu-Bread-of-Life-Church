import 'giving_record.dart';
import 'period_summary.dart';
import 'sunday_income_form.dart';
import 'week_summary.dart';

// Everything user-visible here is plain ASCII so it prints in the PDF font.

/// How a figure moved compared with the previous period.
enum TrendBand { strongRise, rise, steady, dip, fall }

/// A rise or fall of at least this many percent is "strong".
const trendStrongPercent = 10.0;

/// Moves smaller than this many percent, up or down, count as "steady".
const trendSteadyPercent = 2.0;

extension TrendBandX on TrendBand {
  /// The remark shown beside the percentage.
  String get word => switch (this) {
        TrendBand.strongRise => 'Strong improvement',
        TrendBand.rise => 'Improved',
        TrendBand.steady => 'Steady',
        TrendBand.dip => 'Slightly down',
        TrendBand.fall => 'Needs attention',
      };
}

/// One figure this period against the same figure last period.
class Trend {
  const Trend({required this.current, required this.previous});

  final double current;
  final double previous;

  /// Without an earlier figure above zero there is nothing to compare with
  /// (a percentage of zero would be meaningless).
  bool get hasBaseline => previous > 0;

  /// Percent change on one decimal place, or null with no baseline. Rounding
  /// first means the percentage shown and the band chosen always agree.
  double? get percent => hasBaseline
      ? (((current - previous) / previous * 100) * 10).round() / 10
      : null;

  TrendBand? get band {
    final p = percent;
    if (p == null) return null;
    if (p >= trendStrongPercent) return TrendBand.strongRise;
    if (p >= trendSteadyPercent) return TrendBand.rise;
    if (p > -trendSteadyPercent) return TrendBand.steady;
    if (p > -trendStrongPercent) return TrendBand.dip;
    return TrendBand.fall;
  }

  /// `+12.5%`, `-8%`, `0%`, or `n/a` with no baseline.
  String get percentText {
    final p = percent;
    if (p == null) return 'n/a';
    if (p == 0) return '0%';
    final size = p.abs();
    final body = size == size.roundToDouble()
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '${p > 0 ? '+' : '-'}$body%';
  }

  /// The remark in words, e.g. `Strong improvement`.
  String get word => band?.word ?? 'No earlier figure';

  /// A sentence for a headline, e.g.
  /// `Giving is up 12.5% on last Sunday: Strong improvement.`
  String sentence(String subject, String comparedWith) {
    final p = percent;
    if (p == null) {
      return '$subject: no earlier figure to compare with $comparedWith.';
    }
    final move = p == 0
        ? 'level with'
        : '${p > 0 ? 'up' : 'down'} ${percentText.substring(1)} on';
    return '$subject is $move $comparedWith: $word.';
  }
}

/// The figures a comparison is made from, for one week, month or year.
class PeriodFigures {
  const PeriodFigures({
    required this.giving,
    required this.tithe,
    required this.averageAttendance,
    required this.serviceCount,
  });

  /// All giving recorded in the period, in Kwacha.
  final double giving;
  final double tithe;

  /// Attendance per service (so a month with five Sundays is not unfairly
  /// compared with one that has four).
  final double averageAttendance;
  final int serviceCount;

  bool get hasData => giving > 0 || tithe > 0 || serviceCount > 0;

  factory PeriodFigures.fromPeriod(PeriodSummary summary) => PeriodFigures(
        giving: summary.grandTotal,
        tithe: summary.categoryTotals[GivingCategory.tithe] ?? 0,
        averageAttendance: summary.averageAttendance,
        serviceCount: summary.serviceCount,
      );

  /// A single Sunday: its giving plus the attendance on the forms dated into
  /// it (a Sunday can have a morning and an evening form).
  factory PeriodFigures.fromWeek(
    WeekSummary summary,
    Iterable<SundayIncomeForm> weekForms,
  ) {
    final forms = weekForms.toList();
    final people = forms.fold(0, (sum, f) => sum + f.attendanceTotal);
    return PeriodFigures(
      giving: summary.grandTotal,
      tithe: summary.categoryTotals[GivingCategory.tithe] ?? 0,
      averageAttendance: forms.isEmpty ? 0 : people / forms.length,
      serviceCount: forms.length,
    );
  }
}

/// This period set beside the one before it: giving, tithe and attendance,
/// each as a percentage and a remark in words.
class PeriodComparison {
  const PeriodComparison({
    required this.comparedWith,
    required this.giving,
    required this.tithe,
    required this.attendance,
    required this.hasEarlierFigures,
    this.ongoing = false,
  });

  /// What the earlier period is called, e.g. `last Sunday (Nov 15, 2026)`.
  final String comparedWith;
  final Trend giving;
  final Trend tithe;
  final Trend attendance;

  /// False when the earlier period has nothing recorded at all.
  final bool hasEarlierFigures;

  /// True when this period is not over yet. The earlier period is then cut at
  /// the same point, so the two cover the same stretch.
  final bool ongoing;

  /// The one-line summary, led by giving.
  String get headline => giving.sentence('Giving', comparedWith);

  factory PeriodComparison.compare({
    required PeriodFigures current,
    required PeriodFigures previous,
    required String comparedWith,
    bool ongoing = false,
  }) =>
      PeriodComparison(
        comparedWith: comparedWith,
        giving: Trend(current: current.giving, previous: previous.giving),
        tithe: Trend(current: current.tithe, previous: previous.tithe),
        attendance: Trend(
            current: current.averageAttendance,
            previous: previous.averageAttendance),
        hasEarlierFigures: previous.hasData,
        ongoing: ongoing,
      );
}
