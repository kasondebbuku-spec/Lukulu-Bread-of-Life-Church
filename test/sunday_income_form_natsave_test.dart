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

  test('reconciles when reserve minus expenses equals the tithe of tithes', () {
    final form = buildForm(
      tithe: {'100': 29}, // 2900 -> 10% = 290
      expensesReserve: {'100': 34, '50': 1, '20': 1}, // 3400 + 50 + 20 = 3470
      natsave: {'10': 13, '5': 1}, // 130 + 5 = 135
      expenses: const [
        ExpenseEntry(description: 'Missions', amount: 3000),
        ExpenseEntry(description: 'Tissue', amount: 80),
        ExpenseEntry(description: 'Alms giving', amount: 100),
      ], // total 3180; 3470 - 3180 = 290, matches 10% of tithe exactly
    );

    expect(form.expensesReserveTotal(valuesByKey), closeTo(3470, 0.001));
    expect(form.totalExpenses, closeTo(3180, 0.001));
    expect(form.natsaveDeposit(valuesByKey), closeTo(135, 0.001));
    expect(form.totalCollection(valuesByKey), closeTo(425, 0.001)); // 290 + 135
    expect(form.reconciliationVariance(valuesByKey), closeTo(0, 0.001));
    expect(form.isReconciled(valuesByKey), isTrue);
  });

  test('flags a variance when the reserve does not cover expenses plus tithe-of-tithes', () {
    final form = buildForm(
      tithe: {'100': 29}, // 10% = 290
      expensesReserve: {'100': 34, '50': 1, '20': 1}, // 3470
      natsave: const {},
      expenses: const [
        ExpenseEntry(description: 'Missions', amount: 3000),
        ExpenseEntry(description: 'Tissue', amount: 80),
        // Alms giving line forgotten -- reserve no longer reconciles.
      ], // total 3080; 3470 - 3080 = 390, expected 290 -> variance 100
    );

    expect(form.reconciliationVariance(valuesByKey), closeTo(100, 0.001));
    expect(form.isReconciled(valuesByKey), isFalse);
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
