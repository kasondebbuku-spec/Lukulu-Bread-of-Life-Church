import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/providers/display_name_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/week_utils.dart';
import '../../../models/cheque_entry.dart';
import '../../../models/expense_entry.dart';
import '../../../models/forex_entry.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../../../repositories/repository_providers.dart';
import '../zmw_denominations.dart';
import '../../../core/utils/currency_format.dart';
import '../giving_theme.dart';
import '../widgets/signature_pad_field.dart';
import 'income_form_detail_screen.dart';

class _ForexRow {
  ForexCurrency currency = ForexCurrency.usDollar;
  final amountController = TextEditingController();
  void dispose() => amountController.dispose();
}

class _ChequeRow {
  final nameController = TextEditingController();
  final chequeNoController = TextEditingController();
  final amountController = TextEditingController();
  void dispose() {
    nameController.dispose();
    chequeNoController.dispose();
    amountController.dispose();
  }
}

class _ExpenseRow {
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }
}

class SundayIncomeFormScreen extends ConsumerStatefulWidget {
  const SundayIncomeFormScreen({super.key});

  @override
  ConsumerState<SundayIncomeFormScreen> createState() => _SundayIncomeFormScreenState();
}

class _SundayIncomeFormScreenState extends ConsumerState<SundayIncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _serviceDate = sundayOnOrBefore(DateTime.now());
  ServiceType _service = ServiceType.morning;

  final Map<GivingCategory, Map<String, TextEditingController>> _controllers = {
    for (final c in GivingCategory.values)
      c: {for (final d in zmwDenominations) d.key: TextEditingController()},
  };

  final List<_ForexRow> _forexRows = [_ForexRow()];
  final List<_ChequeRow> _chequeRows = [_ChequeRow()];
  final List<_ExpenseRow> _expenseRows = [_ExpenseRow()];

  final Map<String, TextEditingController> _natsaveControllers = {
    for (final d in zmwDenominations) d.key: TextEditingController(),
  };
  final Map<String, TextEditingController> _expensesReserveControllers = {
    for (final d in zmwDenominations) d.key: TextEditingController(),
  };

  final _menController = TextEditingController();
  final _womenController = TextEditingController();
  final _childrenController = TextEditingController();
  final _preparedByController = TextEditingController();
  final _checkedByController = TextEditingController();
  final _collectedByController = TextEditingController();

  final _preparedSignature = SignaturePadField.newController();
  final _checkedSignature = SignaturePadField.newController();
  final _collectedSignature = SignaturePadField.newController();

  bool _saving = false;
  bool _signing = false;

  @override
  void initState() {
    super.initState();
    // The person filling in the form is normally the one who prepared it.
    _preparedByController.text = ref.read(displayNameProvider);
  }

  @override
  void dispose() {
    for (final byDenom in _controllers.values) {
      for (final c in byDenom.values) {
        c.dispose();
      }
    }
    for (final row in _forexRows) {
      row.dispose();
    }
    for (final row in _chequeRows) {
      row.dispose();
    }
    for (final row in _expenseRows) {
      row.dispose();
    }
    for (final c in _natsaveControllers.values) {
      c.dispose();
    }
    for (final c in _expensesReserveControllers.values) {
      c.dispose();
    }
    _menController.dispose();
    _womenController.dispose();
    _childrenController.dispose();
    _preparedByController.dispose();
    _checkedByController.dispose();
    _collectedByController.dispose();
    _preparedSignature.dispose();
    _checkedSignature.dispose();
    _collectedSignature.dispose();
    super.dispose();
  }

  Map<String, double> get _valuesByKey => {
        for (final d in zmwDenominations) d.key: d.value,
      };

  double _denominationTotal(Map<String, TextEditingController> controllers) =>
      zmwDenominations.fold(0.0, (total, d) {
        final n = int.tryParse(controllers[d.key]!.text.trim()) ?? 0;
        return total + n * d.value;
      });

  double get _cashTotal => _controllers.values.fold(
      0.0, (total, controllers) => total + _denominationTotal(controllers));
  double get _forexTotal => _forexRows.fold(
      0.0,
      (total, r) =>
          total +
          ForexEntry(
                  currency: r.currency,
                  amount: double.tryParse(r.amountController.text.trim()) ?? 0)
              .kwachaValue);
  double get _chequesTotal => _chequeRows.fold(
      0.0, (total, r) => total + (double.tryParse(r.amountController.text.trim()) ?? 0));
  double get _grandTotal => _cashTotal + _forexTotal + _chequesTotal;
  double get _natsaveTotal => _denominationTotal(_natsaveControllers);

  double get _titheAmount => _denominationTotal(_controllers[GivingCategory.tithe]!);
  double get _twentyPercentOfTithe => _titheAmount * 0.20;
  double get _expensesReserveTotal => _denominationTotal(_expensesReserveControllers);
  double get _expensesTotal => _expenseRows.fold(
      0.0, (total, r) => total + (double.tryParse(r.amountController.text.trim()) ?? 0));

  /// How far the counted expenses-reserve cash is from covering the itemized
  /// expenses plus the required 20%-of-tithe remittance. Zero reconciles.
  double get _reconciliationVariance =>
      (_expensesReserveTotal - _expensesTotal) - _twentyPercentOfTithe;
  bool get _isReconciled => _reconciliationVariance.abs() <= 0.01;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      selectableDayPredicate: (d) => d.weekday == DateTime.sunday,
    );
    if (picked != null) setState(() => _serviceDate = picked);
  }

  Future<Uint8List?> _signatureBytes(SignatureController c) async =>
      c.isEmpty ? null : c.toPngBytes();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final valuesByKey = _valuesByKey;
      final form = SundayIncomeForm(
        id: '',
        date: _serviceDate,
        service: _service,
        categoryBlocks: {
          for (final c in GivingCategory.values)
            c: CategoryBlock(denominationBreakdown: {
              for (final d in zmwDenominations)
                d.key: int.tryParse(_controllers[c]![d.key]!.text.trim()) ?? 0,
            }),
        },
        forexEntries: _forexRows
            .map((r) => ForexEntry(
                  currency: r.currency,
                  amount: double.tryParse(r.amountController.text.trim()) ?? 0,
                ))
            .where((f) => f.amount > 0)
            .toList(),
        chequeEntries: _chequeRows
            .map((r) => ChequeEntry(
                  name: r.nameController.text.trim(),
                  chequeNo: r.chequeNoController.text.trim(),
                  amount: double.tryParse(r.amountController.text.trim()) ?? 0,
                ))
            .where((c) => c.amount > 0)
            .toList(),
        men: int.parse(_menController.text.trim()),
        women: int.parse(_womenController.text.trim()),
        children: int.parse(_childrenController.text.trim()),
        preparedBy: _preparedByController.text.trim(),
        checkedBy: _checkedByController.text.trim(),
        collectedBy: _collectedByController.text.trim(),
        preparedBySignature: await _signatureBytes(_preparedSignature),
        checkedBySignature: await _signatureBytes(_checkedSignature),
        collectedBySignature: await _signatureBytes(_collectedSignature),
        natsaveBlock: CategoryBlock(denominationBreakdown: {
          for (final d in zmwDenominations)
            d.key: int.tryParse(_natsaveControllers[d.key]!.text.trim()) ?? 0,
        }),
        expensesReserveBlock: CategoryBlock(denominationBreakdown: {
          for (final d in zmwDenominations)
            d.key: int.tryParse(_expensesReserveControllers[d.key]!.text.trim()) ?? 0,
        }),
        expenseEntries: _expenseRows
            .map((r) => ExpenseEntry(
                  description: r.descriptionController.text.trim(),
                  amount: double.tryParse(r.amountController.text.trim()) ?? 0,
                ))
            .where((e) => e.amount > 0)
            .toList(),
      );

      final id = await ref
          .read(incomeFormRepositoryProvider)
          .saveAndCascade(form, valuesByKey);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => IncomeFormDetailScreen(form: form.copyWithId(id)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sunday Income Form')),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: _signing ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                    title: Text('Service Sunday: ${formatDate(_serviceDate)}'),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDate,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        const Text('Service: '),
                        const SizedBox(width: 8),
                        DropdownButton<ServiceType>(
                          value: _service,
                          items: ServiceType.values
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s.label)))
                              .toList(),
                          onChanged: (v) => setState(() => _service = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final c in GivingCategory.values) ...[
              _CategoryTable(
                title: c.label,
                color: categoryColor(c),
                controllers: _controllers[c]!,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            _ForexSection(
              rows: _forexRows,
              onChanged: () => setState(() {}),
              onAddRow: () => setState(() => _forexRows.add(_ForexRow())),
              onRemoveRow: (row) => setState(() {
                row.dispose();
                _forexRows.remove(row);
              }),
            ),
            const SizedBox(height: 12),
            _ChequeSection(
              rows: _chequeRows,
              onChanged: () => setState(() {}),
              onAddRow: () => setState(() => _chequeRows.add(_ChequeRow())),
              onRemoveRow: (row) => setState(() {
                row.dispose();
                _chequeRows.remove(row);
              }),
            ),
            const SizedBox(height: 12),
            _CategoryTable(
              title: 'Natsave Account Deposit',
              color: AppColors.primaryDark,
              controllers: _natsaveControllers,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _CategoryTable(
              title: 'Expenses + Tithe of Tithes Reserve',
              color: AppColors.goldInk,
              controllers: _expensesReserveControllers,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _ExpenseSection(
              rows: _expenseRows,
              onChanged: () => setState(() {}),
              onAddRow: () => setState(() => _expenseRows.add(_ExpenseRow())),
              onRemoveRow: (row) => setState(() {
                row.dispose();
                _expenseRows.remove(row);
              }),
            ),
            const SizedBox(height: 12),
            if (!_isReconciled)
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
                        'Expenses reserve does not reconcile: expected 20% of tithe '
                        '(${formatZmw(_twentyPercentOfTithe)}) but reserve minus '
                        'expenses is ${formatZmw(_expensesReserveTotal - _expensesTotal)} '
                        '(variance ${formatZmw(_reconciliationVariance)}).',
                        style: const TextStyle(color: AppColors.goldInk),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isReconciled) const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _menController,
                            decoration: const InputDecoration(labelText: 'Men'),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _womenController,
                            decoration: const InputDecoration(labelText: 'Women'),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _childrenController,
                            decoration: const InputDecoration(labelText: 'Children'),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign-off', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    TextFormField(
                      controller: _preparedByController,
                      decoration: const InputDecoration(labelText: 'Prepared By'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SignaturePadField(
                      label: 'Prepared By signature (optional)',
                      controller: _preparedSignature,
                      onDrawingChanged: (v) => setState(() => _signing = v),
                    ),
                    TextFormField(
                      controller: _checkedByController,
                      decoration: const InputDecoration(labelText: 'Checked By'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SignaturePadField(
                      label: 'Checked By signature (optional)',
                      controller: _checkedSignature,
                      onDrawingChanged: (v) => setState(() => _signing = v),
                    ),
                    TextFormField(
                      controller: _collectedByController,
                      decoration: const InputDecoration(labelText: 'Collected By'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    SignaturePadField(
                      label: 'Collected By signature (optional)',
                      controller: _collectedSignature,
                      onDrawingChanged: (v) => setState(() => _signing = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Totals (live)', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    _TotalLine('Cash (all categories)', _cashTotal),
                    _TotalLine('Forex (Kwacha value)', _forexTotal),
                    _TotalLine('Cheques', _chequesTotal),
                    _TotalLine('Grand Total', _grandTotal, emphasized: true),
                    const Divider(),
                    _TotalLine('20% of Tithe (remittance)', _twentyPercentOfTithe),
                    _TotalLine('Natsave Deposit', _natsaveTotal),
                    _TotalLine('Total Collection', _twentyPercentOfTithe + _natsaveTotal,
                        emphasized: true),
                    _TotalLine('Total Expenses', _expensesTotal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Form'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.emphasized = false});

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
      fontSize: emphasized ? 16 : 14,
      color: emphasized ? AppColors.primaryDark : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(formatZmw(value), style: style)],
      ),
    );
  }
}

class _CategoryTable extends StatelessWidget {
  const _CategoryTable({
    required this.title,
    required this.color,
    required this.controllers,
    required this.onChanged,
  });

  final String title;
  final Color color;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;

  double get _subtotal => zmwDenominations.fold(0.0, (total, d) {
        final n = int.tryParse(controllers[d.key]!.text.trim()) ?? 0;
        return total + n * d.value;
      });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const Divider(),
            for (final d in zmwDenominations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 72, child: Text(d.label)),
                    Expanded(
                      child: TextFormField(
                        controller: controllers[d.key],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: '0'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sub-total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(formatZmw(_subtotal),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForexSection extends StatelessWidget {
  const _ForexSection({
    required this.rows,
    required this.onChanged,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  final List<_ForexRow> rows;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final ValueChanged<_ForexRow> onRemoveRow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forex', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ForexCurrency>(
                        initialValue: row.currency,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, labelText: 'Currency'),
                        items: ForexCurrency.values
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                            .toList(),
                        onChanged: (v) {
                          row.currency = v!;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Amount'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: rows.length > 1 ? () => onRemoveRow(row) : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseSection extends StatelessWidget {
  const _ExpenseSection({
    required this.rows,
    required this.onChanged,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  final List<_ExpenseRow> rows;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final ValueChanged<_ExpenseRow> onRemoveRow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.descriptionController,
                        decoration:
                            const InputDecoration(isDense: true, labelText: 'Description'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Amount'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: rows.length > 1 ? () => onRemoveRow(row) : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChequeSection extends StatelessWidget {
  const _ChequeSection({
    required this.rows,
    required this.onChanged,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  final List<_ChequeRow> rows;
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final ValueChanged<_ChequeRow> onRemoveRow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cheques', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.nameController,
                        decoration: const InputDecoration(isDense: true, labelText: 'Name'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.chequeNoController,
                        decoration: const InputDecoration(isDense: true, labelText: 'Chq No.'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: row.amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true, labelText: 'Amount'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: rows.length > 1 ? () => onRemoveRow(row) : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add),
              label: const Text('Add row'),
            ),
          ],
        ),
      ),
    );
  }
}
