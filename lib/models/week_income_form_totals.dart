import '../core/utils/week_utils.dart';
import 'sunday_income_form.dart';

/// Tithe of tithes, Natsave and expenses rollup across every [SundayIncomeForm]
/// dated into one week (a Sunday can have a morning and an evening form).
class WeekIncomeFormTotals {
  const WeekIncomeFormTotals({
    required this.formCount,
    required this.natsaveDeposit,
    required this.totalExpenses,
    required this.titheOfTithes,
  });

  final int formCount;
  final double natsaveDeposit;
  final double totalExpenses;
  final double titheOfTithes;

  bool get hasForms => formCount > 0;
  double get totalCollection => titheOfTithes + natsaveDeposit;

  /// Totals for the forms dated into the week starting on [sunday].
  factory WeekIncomeFormTotals.compute(
    DateTime sunday,
    List<SundayIncomeForm> forms,
    Map<String, double> valuesByKey,
  ) =>
      WeekIncomeFormTotals.fromForms(
        forms.where((f) => sundayOnOrBefore(f.date) == sunday),
        valuesByKey,
      );

  /// Totals across exactly the given forms (a week, a month, a year...).
  factory WeekIncomeFormTotals.fromForms(
    Iterable<SundayIncomeForm> forms,
    Map<String, double> valuesByKey,
  ) {
    var count = 0;
    var natsave = 0.0;
    var expenses = 0.0;
    var titheOfTithes = 0.0;

    for (final form in forms) {
      count++;
      natsave += form.natsaveDeposit(valuesByKey);
      expenses += form.totalExpenses;
      titheOfTithes += form.titheOfTithes(valuesByKey);
    }

    return WeekIncomeFormTotals(
      formCount: count,
      natsaveDeposit: natsave,
      totalExpenses: expenses,
      titheOfTithes: titheOfTithes,
    );
  }
}
