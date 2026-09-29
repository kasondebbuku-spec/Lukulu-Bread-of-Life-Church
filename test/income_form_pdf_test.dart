import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/models/expense_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';
import 'package:church_cms/features/giving/pdf/income_form_pdf.dart';

void main() {
  const valuesByKey = {
    '500': 500.0, '200': 200.0, '100': 100.0, '50': 50.0, '20': 20.0,
    '10': 10.0, '5': 5.0, '2': 2.0, '1': 1.0, '0.5': 0.5, '0.1': 0.1, '0.05': 0.05,
  };

  test('renders with Natsave/Expenses Reserve/itemized expenses filled in', () async {
    final form = SundayIncomeForm(
      id: 'test',
      date: DateTime(2026, 9, 27),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
            denominationBreakdown: c == GivingCategory.tithe ? {'100': 29} : const {},
          ),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 40,
      women: 55,
      children: 20,
      preparedBy: 'Inambao Nanzila',
      checkedBy: 'Msiska Isaac',
      collectedBy: 'Mabai Mike',
      natsaveBlock: const CategoryBlock(denominationBreakdown: {'10': 6}),
      expensesReserveBlock: const CategoryBlock(denominationBreakdown: {'1': 3760}),
      expenseEntries: const [ExpenseEntry(description: 'Missions', amount: 3180)],
    );

    final bytes = await buildIncomeFormPdf(form, valuesByKey);
    expect(bytes.isNotEmpty, isTrue);
  });

  test('renders a form with no Natsave/Expenses data (pre-existing saved forms)', () async {
    final form = SundayIncomeForm(
      id: 'old',
      date: DateTime(2026, 1, 4),
      service: ServiceType.morning,
      // Mirrors SundayIncomeForm.fromDoc, which always back-fills every
      // category (even an old document with no categoryBlocks field at all).
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: const CategoryBlock(denominationBreakdown: {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 0,
      women: 0,
      children: 0,
      preparedBy: '',
      checkedBy: '',
      collectedBy: '',
    );

    final bytes = await buildIncomeFormPdf(form, valuesByKey);
    expect(bytes.isNotEmpty, isTrue);
  });
}
