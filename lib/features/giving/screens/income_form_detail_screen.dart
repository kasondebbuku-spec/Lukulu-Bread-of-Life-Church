import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../pdf/income_form_pdf.dart';
import '../zmw_denominations.dart';
import '../../../core/utils/currency_format.dart';
import '../giving_theme.dart';

class IncomeFormDetailScreen extends StatelessWidget {
  const IncomeFormDetailScreen({super.key, required this.form});

  final SundayIncomeForm form;

  Map<String, double> get _valuesByKey => {
        for (final d in zmwDenominations) d.key: d.value,
      };

  @override
  Widget build(BuildContext context) {
    final valuesByKey = _valuesByKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunday Income Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) => buildIncomeFormPdf(form, valuesByKey),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: AppColors.primary),
              title: Text('${formatDate(form.date)} — ${form.service.label} service'),
            ),
          ),
          const SizedBox(height: 16),
          for (final c in GivingCategory.values)
            _Row(
              label: c.label,
              value: form.categoryAmount(c, valuesByKey),
              color: categoryColor(c),
            ),
          if (form.forexEntries.isNotEmpty)
            _Row(
              label: 'Forex (Kwacha value)',
              value: form.totalForexKwacha,
              color: AppColors.blueDark,
            ),
          if (form.chequeEntries.isNotEmpty)
            _Row(label: 'Cheques', value: form.totalCheques, color: AppColors.primaryDark),
          _Row(
            label: 'Natsave Account Deposit',
            value: form.natsaveDeposit(valuesByKey),
            color: AppColors.primaryDark,
          ),
          _Row(
            label: 'Expenses + Tithe of Tithes Reserve',
            value: form.expensesReserveTotal(valuesByKey),
            color: AppColors.goldInk,
          ),
          const Divider(height: 32),
          _Row(
            label: 'Grand Total',
            value: form.grandTotal(valuesByKey),
            color: AppColors.primaryDark,
            emphasized: true,
          ),
          _Row(
            label: '20% of Tithe (remittance)',
            value: form.twentyPercentOfTithe(valuesByKey),
            color: AppColors.secondary,
          ),
          _Row(
            label: 'Natsave Deposit',
            value: form.natsaveDeposit(valuesByKey),
            color: AppColors.primaryDark,
          ),
          _Row(
            label: 'Total Collection',
            value: form.totalCollection(valuesByKey),
            color: AppColors.secondaryDark,
            emphasized: true,
          ),
          if (!form.isReconciled(valuesByKey)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldInk.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.goldInk),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: AppColors.goldInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expenses reserve does not reconcile with expenses plus '
                      'the 20%-of-tithe remittance (variance '
                      '${formatZmw(form.reconciliationVariance(valuesByKey))}).',
                      style: const TextStyle(color: AppColors.goldInk),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (form.expenseEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final e in form.expenseEntries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.description),
                            Text(formatZmw(e.amount)),
                          ],
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(formatZmw(form.totalExpenses),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Men: ${form.men}  •  Women: ${form.women}  •  '
                      'Children: ${form.children}  •  Total: ${form.attendanceTotal}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign-off', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SignedLine('Prepared By', form.preparedBy, form.preparedBySignature),
                  _SignedLine('Checked By', form.checkedBy, form.checkedBySignature),
                  _SignedLine('Collected By', form.collectedBy, form.collectedBySignature),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: emphasized
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              formatZmw(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: emphasized ? 20 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedLine extends StatelessWidget {
  const _SignedLine(this.role, this.name, this.signature);

  final String role;
  final String name;
  final Uint8List? signature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$role: $name'),
          if (signature != null)
            Container(
              height: 70,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(signature!, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}
