import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';

void main() {
  const valuesByKey = {
    '100': 100.0,
    '50': 50.0,
    '20': 20.0,
    '10': 10.0,
    '5': 5.0,
    '2': 2.0,
    '1': 1.0,
    '0.5': 0.5,
    '0.1': 0.1,
    '0.05': 0.05,
  };

  SundayIncomeForm buildForm({
    required Map<String, int> tithe,
    required Map<String, int> expensesReserve,
    required Map<String, int> natsave,
    required List<ExpenseEntry> expenses,
    Map<String, int> titheOfTithesCash = const {},
  }) {
    return SundayIncomeForm(
      id: '',
      date: DateTime(2026, 8, 9),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
            denominationBreakdown: c == GivingCategory.tithe ? tithe : const {},
          ),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 10,
      women: 10,
      children: 5,
      preparedBy: 'A',
      checkedBy: 'B',
      collectedBy: 'C',
      natsaveBlock: CategoryBlock(denominationBreakdown: natsave),
      expensesReserveBlock: CategoryBlock(denominationBreakdown: expensesReserve),
      titheOfTithesBlock: CategoryBlock(denominationBreakdown: titheOfTithesCash),
      expenseEntries: expenses,
    );
  }

  test('titheOfTithes still comes from the tithe category block', () {
    final form = buildForm(
      tithe: {'100': 29}, // K2900, matches the real NATSAVE sheet's tithe subtotal
      expensesReserve: const {},
      natsave: const {},
      expenses: const [],
    );
    expect(form.titheOfTithes(valuesByKey), closeTo(290, 0.001)); // 10% of 2900
  });

  test('the tithe of tithes is exactly 10% of the tithe, and not an expense', () {
    expect(titheOfTithesRate, 0.10);
    final form = buildForm(
      tithe: {'100': 10}, // K1,000 -> K100
      expensesReserve: const {},
      natsave: const {},
      expenses: const [ExpenseEntry(description: 'Tissue', amount: 80)],
    );
    expect(form.titheOfTithes(valuesByKey), closeTo(100, 0.001));
    // It is calculated, so it never appears among the itemised expenses.
    expect(form.totalExpenses, 80);
    expect(form.expenseEntries.map((e) => e.description), ['Tissue']);
    // No tithe, no tithe of tithes.
    expect(
        buildForm(
          tithe: const {},
          expensesReserve: const {},
          natsave: const {},
          expenses: const [],
        ).titheOfTithes(valuesByKey),
        0);
  });

  const threeExpenses = [
    ExpenseEntry(description: 'Missions', amount: 3000),
    ExpenseEntry(description: 'Tissue', amount: 80),
    ExpenseEntry(description: 'Alms giving', amount: 100),
  ]; // total 3180
  const expensesCash3180 = {'100': 31, '50': 1, '20': 1, '10': 1}; // 3180
  const titheOfTithesCash290 = {'100': 2, '50': 1, '20': 2}; // 290

  test('expenses are checked against expenses only', () {
    final form = buildForm(
      tithe: {'100': 29}, // 2900 -> tithe of tithes 290, kept out of expenses
      expensesReserve: expensesCash3180,
      natsave: {'10': 13, '5': 1}, // 135
      expenses: threeExpenses,
    );

    expect(form.expensesReserveTotal(valuesByKey), closeTo(3180, 0.001));
    expect(form.totalExpenses, closeTo(3180, 0.001));
    expect(form.expensesVariance(valuesByKey), closeTo(0, 0.001));
    expect(form.isExpensesReconciled(valuesByKey), isTrue);
    // The tithe of tithes plays no part in the expenses check.
    expect(form.titheOfTithes(valuesByKey), closeTo(290, 0.001));
    expect(form.isReconciled(valuesByKey), isTrue);
    expect(form.natsaveDeposit(valuesByKey), closeTo(135, 0.001));
    expect(form.totalCollection(valuesByKey), closeTo(425, 0.001)); // 290 + 135
  });

  test('flags an expenses variance when a listed expense is missing', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      natsave: const {},
      expenses: const [
        ExpenseEntry(description: 'Missions', amount: 3000),
        ExpenseEntry(description: 'Tissue', amount: 80),
        // Alms giving line forgotten -- the cash no longer matches the list.
      ], // total 3080; 3180 - 3080 -> variance 100
    );

    expect(form.expensesVariance(valuesByKey), closeTo(100, 0.001));
    expect(form.isExpensesReconciled(valuesByKey), isFalse);
    expect(form.isReconciled(valuesByKey), isFalse);
    // The tithe of tithes is unaffected by an expenses problem.
    expect(form.isTitheOfTithesReconciled(valuesByKey), isTrue);
  });

  test('the tithe of tithes cash count is optional and checked on its own', () {
    // No count entered -> nothing to check.
    final none = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      natsave: const {},
      expenses: threeExpenses,
    );
    expect(none.hasTitheOfTithesCount, isFalse);
    expect(none.isTitheOfTithesReconciled(valuesByKey), isTrue);

    // A count that matches the calculated 10%.
    final matching = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      natsave: const {},
      expenses: threeExpenses,
      titheOfTithesCash: titheOfTithesCash290,
    );
    expect(matching.hasTitheOfTithesCount, isTrue);
    expect(matching.titheOfTithesCashTotal(valuesByKey), closeTo(290, 0.001));
    expect(matching.titheOfTithesVariance(valuesByKey), closeTo(0, 0.001));
    expect(matching.isReconciled(valuesByKey), isTrue);

    // A count that is short by K10.
    final short = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      natsave: const {},
      expenses: threeExpenses,
      titheOfTithesCash: {'100': 2, '50': 1, '20': 1, '10': 1}, // 280
    );
    expect(short.titheOfTithesVariance(valuesByKey), closeTo(-10, 0.001));
    expect(short.isTitheOfTithesReconciled(valuesByKey), isFalse);
    expect(short.isReconciled(valuesByKey), isFalse);
    // ...and that does not disturb the expenses check.
    expect(short.isExpensesReconciled(valuesByKey), isTrue);
  });

  test('the tithe of tithes count is saved and reloaded with the form', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      natsave: const {},
      expenses: threeExpenses,
      titheOfTithesCash: titheOfTithesCash290,
    );
    expect(form.toMap()['titheOfTithesBlock'], isNotNull);
    expect(form.copyWithId('x').titheOfTithesCashTotal(valuesByKey),
        closeTo(290, 0.001));
  });

  test('round-trips new fields through toMap without dropping data', () {
    final original = buildForm(
      tithe: {'100': 29},
      expensesReserve: {'100': 37, '10': 6},
      natsave: {'10': 13, '5': 1},
      expenses: const [ExpenseEntry(description: 'Missions', amount: 3000)],
    );

    final map = original.toMap();
    expect(map['natsaveBlock'], isNotNull);
    expect(map['expensesReserveBlock'], isNotNull);
    expect((map['expenseEntries'] as List).length, 1);

    final copied = original.copyWithId('new-id');
    expect(copied.natsaveDeposit(valuesByKey), original.natsaveDeposit(valuesByKey));
    expect(copied.expensesReserveTotal(valuesByKey), original.expensesReserveTotal(valuesByKey));
    expect(copied.totalExpenses, original.totalExpenses);
  });

  test('a form with no Natsave/expenses data (pre-existing saved forms) defaults cleanly', () {
    final form = SundayIncomeForm(
      id: 'old',
      date: DateTime(2026, 1, 4),
      service: ServiceType.morning,
      categoryBlocks: const {},
      forexEntries: const [],
      chequeEntries: const [],
      men: 0,
      women: 0,
      children: 0,
      preparedBy: '',
      checkedBy: '',
      collectedBy: '',
    );

    expect(form.natsaveDeposit(valuesByKey), 0);
    expect(form.expensesReserveTotal(valuesByKey), 0);
    expect(form.totalExpenses, 0);
    expect(form.isReconciled(valuesByKey), isTrue); // 0 - 0 - 0 = 0
  });
}
