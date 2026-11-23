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
      expensesReserveBlock: CategoryBlock(denominationBreakdown: expensesReserve),
      expenseEntries: expenses,
    );
  }

  test('titheOfTithes comes from the tithe category block', () {
    final form = buildForm(
      tithe: {'100': 29}, // K2900
      expensesReserve: const {},
      expenses: const [],
    );
    expect(form.titheOfTithes(valuesByKey), closeTo(290, 0.001)); // 10% of 2900
  });

  test('the tithe of tithes is exactly 10% of the tithe, and not an expense', () {
    expect(titheOfTithesRate, 0.10);
    final form = buildForm(
      tithe: {'100': 10}, // K1,000 -> K100
      expensesReserve: const {},
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
          expenses: const [],
        ).titheOfTithes(valuesByKey),
        0);
  });

  group('Natsave deposit: the rest', () {
    test('is the grand total less the tithe of tithes and less the expenses', () {
      final form = buildForm(
        tithe: {'100': 29}, // everything received: K2,900
        expensesReserve: const {},
        expenses: const [
          ExpenseEntry(description: 'Missions', amount: 500),
          ExpenseEntry(description: 'Tissue', amount: 80),
        ], // K580
      );
      expect(form.grandTotal(valuesByKey), closeTo(2900, 0.001));
      expect(form.titheOfTithes(valuesByKey), closeTo(290, 0.001));
      expect(form.totalExpenses, closeTo(580, 0.001));
      // 2900 - 290 - 580
      expect(form.natsaveDeposit(valuesByKey), closeTo(2030, 0.001));
    });

    test('with no expenses it is the grand total less the tithe of tithes', () {
      final form = buildForm(
        tithe: {'100': 10}, // K1,000
        expensesReserve: const {},
        expenses: const [],
      );
      expect(form.natsaveDeposit(valuesByKey), closeTo(900, 0.001));
    });

    test('with nothing received it is zero', () {
      final form = buildForm(
          tithe: const {}, expensesReserve: const {}, expenses: const []);
      expect(form.natsaveDeposit(valuesByKey), 0);
    });

    test('goes negative, rather than hiding it, when expenses outrun the money received',
        () {
      final form = buildForm(
        tithe: {'100': 10}, // K1,000, tithe of tithes K100
        expensesReserve: const {},
        expenses: const [ExpenseEntry(description: 'Roof', amount: 1200)],
      );
      expect(form.natsaveDeposit(valuesByKey), closeTo(-300, 0.001));
    });

    test('plus the tithe of tithes makes the total collection, which is the net amount',
        () {
      final form = buildForm(
        tithe: {'100': 29},
        expensesReserve: const {},
        expenses: const [ExpenseEntry(description: 'Missions', amount: 580)],
      );
      expect(form.totalCollection(valuesByKey), closeTo(2320, 0.001));
      expect(form.totalCollection(valuesByKey),
          closeTo(form.netAmount(valuesByKey), 0.001));
    });
  });

  test('the net amount is the grand total less the expenses', () {
    final form = buildForm(
      tithe: {'100': 29}, // grand total 2900
      expensesReserve: const {},
      expenses: const [
        ExpenseEntry(description: 'Missions', amount: 500),
        ExpenseEntry(description: 'Tissue', amount: 80),
      ], // 580
    );
    expect(form.grandTotal(valuesByKey), closeTo(2900, 0.001));
    expect(form.totalExpenses, closeTo(580, 0.001));
    expect(form.netAmount(valuesByKey), closeTo(2320, 0.001));
    // The tithe of tithes (290) is not taken off the net amount.
    expect(form.titheOfTithes(valuesByKey), closeTo(290, 0.001));
  });

  test('with no expenses the net amount equals the grand total', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: const {},
      expenses: const [],
    );
    expect(form.netAmount(valuesByKey), form.grandTotal(valuesByKey));
  });

  const threeExpenses = [
    ExpenseEntry(description: 'Missions', amount: 3000),
    ExpenseEntry(description: 'Tissue', amount: 80),
    ExpenseEntry(description: 'Alms giving', amount: 100),
  ]; // total 3180
  const expensesCash3180 = {'100': 31, '50': 1, '20': 1, '10': 1}; // 3180

  test('expenses are checked against expenses only', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      expenses: threeExpenses,
    );

    expect(form.expensesReserveTotal(valuesByKey), closeTo(3180, 0.001));
    expect(form.totalExpenses, closeTo(3180, 0.001));
    expect(form.expensesVariance(valuesByKey), closeTo(0, 0.001));
    expect(form.isExpensesReconciled(valuesByKey), isTrue);
    // The tithe of tithes and the Natsave deposit play no part in this check.
    expect(form.isReconciled(valuesByKey), isTrue);
  });

  test('flags an expenses variance when a listed expense is missing', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      expenses: const [
        ExpenseEntry(description: 'Missions', amount: 3000),
        ExpenseEntry(description: 'Tissue', amount: 80),
        // Alms giving line forgotten -- the cash no longer matches the list.
      ], // total 3080; 3180 - 3080 -> variance 100
    );

    expect(form.expensesVariance(valuesByKey), closeTo(100, 0.001));
    expect(form.isExpensesReconciled(valuesByKey), isFalse);
    expect(form.isReconciled(valuesByKey), isFalse);
  });

  test('the counts that were removed are no longer saved', () {
    final form = buildForm(
      tithe: {'100': 29},
      expensesReserve: expensesCash3180,
      expenses: threeExpenses,
    );
    final map = form.toMap();
    expect(map.containsKey('natsaveBlock'), isFalse);
    expect(map.containsKey('titheOfTithesBlock'), isFalse);
    expect(map['expensesReserveBlock'], isNotNull);
  });

  test('round-trips through toMap and copyWithId without dropping data', () {
    final original = buildForm(
      tithe: {'100': 29},
      expensesReserve: {'100': 37, '10': 6},
      expenses: const [ExpenseEntry(description: 'Missions', amount: 3000)],
    );

    final map = original.toMap();
    expect(map['expensesReserveBlock'], isNotNull);
    expect((map['expenseEntries'] as List).length, 1);

    final copied = original.copyWithId('new-id');
    expect(copied.natsaveDeposit(valuesByKey), original.natsaveDeposit(valuesByKey));
    expect(copied.expensesReserveTotal(valuesByKey), original.expensesReserveTotal(valuesByKey));
    expect(copied.totalExpenses, original.totalExpenses);
  });

  test('a form with no expenses data (pre-existing saved forms) defaults cleanly', () {
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
    expect(form.expensesReserveTotal(valuesByKey), 0);
    expect(form.natsaveDeposit(valuesByKey), 0);
    expect(form.totalExpenses, 0);
    expect(form.isReconciled(valuesByKey), isTrue);
  });
}
