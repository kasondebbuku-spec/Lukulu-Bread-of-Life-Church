import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/providers/audit_actor_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/file_upload_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/week_utils.dart';
import '../../../core/widgets/warning_box.dart';
import '../../../models/cheque_entry.dart';
import '../../../models/expense_entry.dart';
import '../../../models/forex_entry.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../../../repositories/repository_providers.dart';
import '../zmw_denominations.dart';
import '../../../core/utils/currency_format.dart';
import '../giving_theme.dart';
import '../import/income_sheet_parser.dart';
import '../widgets/overall_income_card.dart';
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
  /// Pass [initialForm] to edit a saved form instead of entering a new one.
  const SundayIncomeFormScreen({super.key, this.initialForm});

  final SundayIncomeForm? initialForm;

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

  /// Why the last Save did nothing (missing fields) or failed, shown right above
  /// the Save button where the person is looking.
  String? _saveMessage;
  final _attendanceKey = GlobalKey();
  final _signoffKey = GlobalKey();

  /// What the last Excel import read (and anything worth checking), or why it
  /// could not be read. Shown at the top of the form until dismissed.
  List<String>? _importNotes;
  String? _importError;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialForm;
    if (existing != null) {
      _prefill(existing);
    } else {
      // The person filling in the form is normally the one who prepared it.
      _preparedByController.text = ref.read(displayNameProvider);
    }
  }

  bool get _editing => widget.initialForm != null;

  static String _count(int? n) => (n == null || n == 0) ? '' : '$n';

  void _fillDenominations(
      Map<String, TextEditingController> controllers, CategoryBlock? block) {
    for (final d in zmwDenominations) {
      controllers[d.key]!.text = _count(block?.denominationBreakdown[d.key]);
    }
  }

  void _prefill(SundayIncomeForm form) {
    _serviceDate = form.date;
    _service = form.service;
    for (final c in GivingCategory.values) {
      _fillDenominations(_controllers[c]!, form.categoryBlocks[c]);
    }
    _fillDenominations(_expensesReserveControllers, form.expensesReserveBlock);

    String money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

    if (form.forexEntries.isNotEmpty) {
      for (final r in _forexRows) {
        r.dispose();
      }
      _forexRows
        ..clear()
        ..addAll(form.forexEntries.map((f) => _ForexRow()
          ..currency = f.currency
          ..amountController.text = money(f.amount)));
    }
    if (form.chequeEntries.isNotEmpty) {
      for (final r in _chequeRows) {
        r.dispose();
      }
      _chequeRows
        ..clear()
        ..addAll(form.chequeEntries.map((c) => _ChequeRow()
          ..nameController.text = c.name
          ..chequeNoController.text = c.chequeNo
          ..amountController.text = money(c.amount)));
    }
    if (form.expenseEntries.isNotEmpty) {
      for (final r in _expenseRows) {
        r.dispose();
      }
      _expenseRows
        ..clear()
        ..addAll(form.expenseEntries.map((e) => _ExpenseRow()
          ..descriptionController.text = e.description
          ..amountController.text = money(e.amount)));
    }

    _menController.text = '${form.men}';
    _womenController.text = '${form.women}';
    _childrenController.text = '${form.children}';
    _preparedByController.text = form.preparedBy;
    _checkedByController.text = form.checkedBy;
    _collectedByController.text = form.collectedBy;
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

  /// All the K500s, all the K200s ... counted across tithe, offering, seed,
  /// thanksgiving and pledge together.
  Map<String, int> get _overallCounts => {
        for (final d in zmwDenominations)
          d.key: GivingCategory.values.fold(
              0,
              (sum, c) =>
                  sum + (int.tryParse(_controllers[c]![d.key]!.text.trim()) ?? 0)),
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

  double get _titheAmount => _denominationTotal(_controllers[GivingCategory.tithe]!);
  double get _titheOfTithes => _titheAmount * titheOfTithesRate;
  double get _expensesReserveTotal => _denominationTotal(_expensesReserveControllers);
  double get _expensesTotal => _expenseRows.fold(
      0.0, (total, r) => total + (double.tryParse(r.amountController.text.trim()) ?? 0));

  /// What goes into the Natsave account: everything received, less the tithe
  /// of tithes, less the expenses. Calculated, never typed in.
  double get _natsaveTotal => _grandTotal - _titheOfTithes - _expensesTotal;

  /// Expenses are checked against expenses only: cash set aside minus the
  /// itemised expenses. Zero reconciles.
  double get _expensesVariance => _expensesReserveTotal - _expensesTotal;
  bool get _isExpensesReconciled => _expensesVariance.abs() <= 0.01;

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

  String _signatureLabel(String role, Uint8List? saved) => saved == null
      ? '$role signature (optional)'
      : '$role signature -- saved one is kept unless you draw a new one';

  Future<Uint8List?> _signatureBytes(SignatureController c) async =>
      c.isEmpty ? null : c.toPngBytes();

  bool get _hasEntries =>
      _controllers.values
          .any((byNote) => byNote.values.any((c) => c.text.trim().isNotEmpty)) ||
      _expenseRows.any((r) =>
          r.descriptionController.text.trim().isNotEmpty ||
          r.amountController.text.trim().isNotEmpty);

  /// Lets the person choose the Sunday income sheet (.xlsx) and fills the form
  /// from it. It never saves: the figures are there to be checked first.
  Future<void> _importFromSheet() async {
    final picker = ref.read(spreadsheetPickerProvider);
    final IncomeSheetImport result;
    try {
      final bytes = await picker();
      if (bytes == null || !mounted) return; // chooser closed without a file
      result = parseIncomeSheet(bytes);
    } on IncomeSheetFormatException catch (e) {
      if (mounted) {
        setState(() {
          _importNotes = null;
          _importError = e.message;
        });
      }
      return;
    } on UnsupportedError {
      if (mounted) {
        setState(() =>
            _importError = 'Importing a sheet only works in the web app.');
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _importError =
            'That file could not be read. Please choose the Sunday income sheet saved as an Excel .xlsx file.');
      }
      return;
    }
    if (!mounted) return;

    if (_hasEntries) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace what you have entered?'),
          content: const Text(
              'The counts and expenses already on this form will be replaced by the sheet.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep mine')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    _applyImport(result);
  }

  void _applyImport(IncomeSheetImport r) {
    String money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    final notes = <String>[];

    setState(() {
      // Every category: those the sheet has are filled, the rest are cleared, so
      // nothing typed earlier is left mixed in with the sheet's figures.
      for (final c in GivingCategory.values) {
        final byNote = r.counts[c] ?? const <String, int>{};
        for (final d in zmwDenominations) {
          _controllers[c]![d.key]!.text = _count(byNote[d.key]);
        }
      }

      for (final row in _expenseRows) {
        row.dispose();
      }
      _expenseRows
        ..clear()
        ..addAll(r.expenses.isEmpty
            ? [_ExpenseRow()]
            : r.expenses.map((e) => _ExpenseRow()
              ..descriptionController.text = e.description
              ..amountController.text = money(e.amount)));

      if (r.preparedBy != null) _preparedByController.text = r.preparedBy!;
      if (r.checkedBy != null) _checkedByController.text = r.checkedBy!;
      if (r.collectedBy != null) _collectedByController.text = r.collectedBy!;

      if (r.date != null) {
        final sunday = sundayOnOrBefore(r.date!);
        _serviceDate = sunday;
        if (sunday != DateTime(r.date!.year, r.date!.month, r.date!.day)) {
          notes.add("The sheet's date (${formatDate(r.date!)}) is not a Sunday, "
              'so the Sunday before it was used.');
        }
      } else {
        notes.add('No date was found on the sheet; check the service Sunday above.');
      }
      if (r.service != null) {
        _service = r.service!;
      } else {
        notes.add('No service (Morning or Evening) was found on the sheet; check it above.');
      }

      final read = [
        for (final c in GivingCategory.values)
          if ((r.counts[c] ?? const {}).isNotEmpty)
            '${c.label} ${formatZmw(_denominationTotal(_controllers[c]!))}',
      ];
      notes.insert(
          0, 'Read from the sheet: ${read.join(', ')}. Overall cash ${formatZmw(_cashTotal)}.');
      notes.insert(
          1,
          r.expenses.isEmpty
              ? 'No expenses were found on the sheet.'
              : '${r.expenses.length} expense${r.expenses.length == 1 ? '' : 's'} read, '
                  'total ${formatZmw(_expensesTotal)}.');
      notes.addAll(r.warnings);
      final missing = _missingRequired();
      if (missing.isNotEmpty) {
        notes.add('Not on the sheet, so please fill in: ${missing.join(', ')}.');
      }

      _importError = null;
      _importNotes = notes;
      _saveMessage = null;
    });
  }

  /// The required fields still empty, in the order they appear on the form.
  List<String> _missingRequired() => [
        if (int.tryParse(_menController.text.trim()) == null) 'Men',
        if (int.tryParse(_womenController.text.trim()) == null) 'Women',
        if (int.tryParse(_childrenController.text.trim()) == null) 'Children',
        if (_preparedByController.text.trim().isEmpty) 'Prepared By',
        if (_checkedByController.text.trim().isEmpty) 'Checked By',
        if (_collectedByController.text.trim().isEmpty) 'Collected By',
      ];

  /// Takes the person to the first section that needs filling in.
  void _scrollToProblem(List<String> missing) {
    final attendanceMissing =
        missing.any((m) => m == 'Men' || m == 'Women' || m == 'Children');
    final target = (attendanceMissing ? _attendanceKey : _signoffKey).currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350), alignment: 0.05);
    }
  }

  String _friendlyError(Object e) {
    if (e is StateError) return e.message;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'your account is not allowed to save Sunday income forms.';
      }
      if (e.code == 'unavailable') {
        return 'there is no connection right now.';
      }
    }
    return 'please check your connection and try again.';
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) {
      // Saving did not happen. Say so where the person is looking (the Save
      // button is at the bottom, the empty fields are higher up), then take
      // them to the first one.
      final missing = _missingRequired();
      setState(() => _saveMessage = missing.isEmpty
          ? 'Not saved yet. Please check the highlighted fields above.'
          : 'Not saved yet. Please fill in: ${missing.join(', ')}.');
      _scrollToProblem(missing);
      return;
    }
    setState(() {
      _saving = true;
      _saveMessage = null;
    });

    try {
      final actor = ref.read(auditActorProvider);
      if (actor == null) {
        throw StateError('You must be signed in to save a form.');
      }
      final valuesByKey = _valuesByKey;
      final form = SundayIncomeForm(
        id: widget.initialForm?.id ?? '',
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
        preparedBySignature: await _signatureBytes(_preparedSignature) ??
            widget.initialForm?.preparedBySignature,
        checkedBySignature: await _signatureBytes(_checkedSignature) ??
            widget.initialForm?.checkedBySignature,
        collectedBySignature: await _signatureBytes(_collectedSignature) ??
            widget.initialForm?.collectedBySignature,
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
        // Who typed it in: the person saving it now, or whoever first saved it.
        enteredBy: widget.initialForm?.enteredBy ?? actor.name,
        enteredByUid: widget.initialForm?.enteredByUid ?? actor.uid,
      );

      final repository = ref.read(incomeFormRepositoryProvider);
      final String id;
      if (_editing) {
        await repository.updateAndCascade(form, valuesByKey,
            previous: widget.initialForm!, actor: actor);
        id = form.id;
      } else {
        id = await repository.saveAndCascade(form, valuesByKey, actor: actor);
      }

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Saved. You can find it again in Giving > Sunday Income Forms.'),
      ));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => IncomeFormDetailScreen(form: form.copyWithId(id)),
        ),
      );
    } catch (e) {
      // Nothing was saved: say so in words, instead of failing silently.
      if (mounted) {
        setState(() =>
            _saveMessage = 'Could not save: ${_friendlyError(e)} Nothing was saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing ? 'Edit Sunday Income Form' : 'Sunday Income Form')),
      body: Form(
        key: _formKey,
        child: ListView(
          // Build the whole form so Save can scroll to a field that needs filling
          // in, however far up it is.
          cacheExtent: 30000,
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
            const SizedBox(height: 12),
            // Fill the form from the Finance team's Excel sheet instead of typing
            // it all again. New forms only; an edit keeps what was saved.
            if (!_editing) ...[
              OutlinedButton.icon(
                key: const Key('import-sheet'),
                onPressed: _saving ? null : _importFromSheet,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import from Excel sheet'),
              ),
              const SizedBox(height: 12),
            ],
            if (_importError != null) ...[
              WarningBox(_importError!),
              const SizedBox(height: 12),
            ],
            if (_importNotes != null) ...[
              Card(
                key: const Key('import-notes'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fact_check_outlined,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Filled in from the Excel sheet. Please check every figure, then Save.',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final note in _importNotes!)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(note),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _importNotes = null),
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final c in GivingCategory.values) ...[
              _CategoryTable(
                title: c.label,
                color: categoryColor(c),
                controllers: _controllers[c]!,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            OverallIncomeCard(counts: _overallCounts),
            const SizedBox(height: 12),
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
              title: 'Expenses Cash Count',
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
            if (!_isExpensesReconciled) ...[
              WarningBox(
                  'Expenses cash does not match the listed expenses: '
                  '${formatZmw(_expensesReserveTotal)} counted against '
                  '${formatZmw(_expensesTotal)} listed '
                  '(variance ${formatZmw(_expensesVariance)}).'),
              const SizedBox(height: 12),
            ],
            // After everything is received, the tithe of tithes and the expenses
            // are taken out; the rest goes into the Natsave account. Both are
            // worked out for you, so there is nothing to count here.
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.volunteer_activism_outlined,
                        color: AppColors.secondary),
                    title: Text(
                        'Tithe of Tithes (10% of tithe): ${formatZmw(_titheOfTithes)}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined,
                        color: AppColors.primaryDark),
                    title: Text('Natsave Deposit: ${formatZmw(_natsaveTotal)}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              key: _attendanceKey,
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
              key: _signoffKey,
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
                      label: _signatureLabel('Prepared By', widget.initialForm?.preparedBySignature),
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
                      label: _signatureLabel('Checked By', widget.initialForm?.checkedBySignature),
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
                      label: _signatureLabel('Collected By', widget.initialForm?.collectedBySignature),
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
                    _TotalLine('Less: Total Expenses', _expensesTotal),
                    _TotalLine('Net Amount', _grandTotal - _expensesTotal,
                        emphasized: true),
                    const Divider(),
                    _TotalLine('Tithe of Tithes (10% of tithe)', _titheOfTithes),
                    _TotalLine('Natsave Deposit', _natsaveTotal),
                    _TotalLine('Total Collection', _titheOfTithes + _natsaveTotal,
                        emphasized: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_saveMessage != null) ...[
              WarningBox(_saveMessage!),
              const SizedBox(height: 12),
            ],
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
        children: [
          // The label wraps rather than overflowing on a narrow phone.
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(formatZmw(value), style: style),
        ],
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
