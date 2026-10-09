import '../core/utils/week_utils.dart';
import 'sunday_income_form.dart';

/// Natsave/expenses rollup across every [SundayIncomeForm] dated into one
/// week (a Sunday can have a morning and an evening form).
class WeekIncomeFormTotals {
  const WeekIncomeFormTotals({
    required this.formCount,
    required this.natsaveDeposit,
    required this.expensesReserve,
    required this.totalExpenses,
    required this.titheOfTithes,
    required this.unreconciledCount,
  });

  final int formCount;
  final double natsaveDeposit;
  final double expensesReserve;
  final double totalExpenses;
  final double titheOfTithes;

  /// Forms whose reserve minus expenses doesn't match the 20%-of-tithe figure.
  final int unreconciledCount;

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
    var reserve = 0.0;
    var expenses = 0.0;
    var titheOfTithes = 0.0;
    var unreconciled = 0;

    for (final form in forms) {
      count++;
      natsave += form.natsaveDeposit(valuesByKey);
      reserve += form.expensesReserveTotal(valuesByKey);
      expenses += form.totalExpenses;
      titheOfTithes += form.twentyPercentOfTithe(valuesByKey);
      if (!form.isReconciled(valuesByKey)) unreconciled++;
    }

    return WeekIncomeFormTotals(
      formCount: count,
      natsaveDeposit: natsave,
      expensesReserve: reserve,
      totalExpenses: expenses,
      titheOfTithes: titheOfTithes,
      unreconciledCount: unreconciled,
    );
  }
}
