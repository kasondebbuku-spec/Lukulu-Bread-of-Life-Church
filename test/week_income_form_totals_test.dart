import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/models/week_income_form_totals.dart';

void main() {
  const valuesByKey = {'100': 100.0, '10': 10.0, '1': 1.0};

  SundayIncomeForm form({
    required DateTime date,
    required int tithe100,
    required int reserve1,
    required double expense,
    ServiceType service = ServiceType.morning,
  }) {
    return SundayIncomeForm(
      id: '',
      date: date,
      service: service,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
            denominationBreakdown:
                c == GivingCategory.tithe ? {'100': tithe100} : const {},
          ),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 0,
      women: 0,
      children: 0,
      preparedBy: 'a',
      checkedBy: 'b',
      collectedBy: 'c',
      expensesReserveBlock: CategoryBlock(denominationBreakdown: {'1': reserve1}),
      expenseEntries: [ExpenseEntry(description: 'x', amount: expense)],
    );
  }

  final sunday = DateTime(2026, 9, 27);

  test('sums only forms dated into the selected week', () {
    final forms = [
      // Balanced: the expenses cash (580) matches the listed expenses (580).
      form(date: sunday, tithe100: 29, reserve1: 580, expense: 580),
      // Evening service, same Sunday, also balanced: cash 300, expenses 300.
      form(
          date: sunday,
          tithe100: 10,
          reserve1: 300,
          expense: 300,
          service: ServiceType.evening),
      // Different week -- must be ignored.
      form(
          date: DateTime(2026, 9, 20),
          tithe100: 50,
          reserve1: 9999,
          expense: 1),
    ];

    final totals = WeekIncomeFormTotals.compute(sunday, forms, valuesByKey);

    expect(totals.formCount, 2);
    expect(totals.titheOfTithes, closeTo(390, 0.001)); // 290 + 100
    // Natsave is the rest of each Sunday: (2900 - 290 - 580) + (1000 - 100 - 300).
    expect(totals.natsaveDeposit, closeTo(2630, 0.001)); // 2030 + 600
    // Tithe of tithes plus Natsave is what was received less the expenses.
    expect(totals.totalCollection, closeTo(3020, 0.001)); // 390 + 2630
    expect(totals.expensesReserve, closeTo(880, 0.001)); // 580 + 300
    expect(totals.totalExpenses, closeTo(880, 0.001)); // 580 + 300
    expect(totals.unreconciledCount, 0);
  });

  test('counts forms that do not reconcile', () {
    final totals = WeekIncomeFormTotals.compute(
      sunday,
      [form(date: sunday, tithe100: 29, reserve1: 3000, expense: 3180)],
      valuesByKey,
    );
    expect(totals.unreconciledCount, 1);
  });

  test('a week with no forms reports hasForms false', () {
    final totals = WeekIncomeFormTotals.compute(sunday, const [], valuesByKey);
    expect(totals.hasForms, isFalse);
    expect(totals.totalCollection, 0);
  });
}
