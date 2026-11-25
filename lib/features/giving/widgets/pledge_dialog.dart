import 'package:flutter/material.dart';

import '../../../core/utils/date_format.dart';
import '../../../models/pledge.dart';
import '../../members/screens/account_roles_screen.dart';

/// What the pledge dialog hands back.
class PledgeDraft {
  const PledgeDraft({
    required this.amount,
    required this.dueDate,
    required this.note,
    this.account,
    this.guestName,
  });

  final double amount;
  final DateTime dueDate;
  final String note;

  /// Whose pledge it is, when the Finance Officer is recording it for a member.
  final RegisteredAccount? account;

  /// Set instead of [account] when the pledge is for someone who has not
  /// registered: their name as the Finance Officer typed it.
  final String? guestName;
}

const pledgeMaxAmount = 10000000.0;
const pledgeNoteMaxLength = 200;

/// Asks for a pledge's amount, due date and an optional note. Pass [accounts]
/// when recording on a member's behalf (the Finance Officer chooses whose);
/// leave it null for a member making their own. Pass [existing] to change one.
Future<PledgeDraft?> showPledgeDialog(
  BuildContext context, {
  Pledge? existing,
  List<RegisteredAccount>? accounts,
}) =>
    showDialog<PledgeDraft>(
      context: context,
      builder: (context) => _PledgeDialog(existing: existing, accounts: accounts),
    );

class _PledgeDialog extends StatefulWidget {
  const _PledgeDialog({this.existing, this.accounts});

  final Pledge? existing;
  final List<RegisteredAccount>? accounts;

  @override
  State<_PledgeDialog> createState() => _PledgeDialogState();
}

class _PledgeDialogState extends State<_PledgeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : _plain(widget.existing!.amount));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _due = widget.existing?.dueDate ??
      DateTime.now().add(const Duration(days: 30));
  late final _guestName = TextEditingController();
  RegisteredAccount? _account;
  bool _guest = false;
  String? _dateError;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _guestName.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) {
      setState(() {
        _due = DateTime(picked.year, picked.month, picked.day);
        _dateError = null;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PledgeDraft(
        amount: double.parse(_amount.text.trim()),
        dueDate: DateTime(_due.year, _due.month, _due.day),
        note: _note.text.trim(),
        account: _guest ? null : _account,
        guestName: _guest ? _guestName.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New pledge' : 'Change pledge'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accounts != null) ...[
                SwitchListTile(
                  key: const Key('pledge-not-registered'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Not registered in the app'),
                  subtitle: const Text(
                      'Finance records what they give, by hand.'),
                  value: _guest,
                  onChanged: (v) => setState(() => _guest = v),
                ),
                if (_guest)
                  TextFormField(
                    key: const Key('pledge-guest-name'),
                    controller: _guestName,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Their full name'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter their name' : null,
                  )
                else
                  DropdownButtonFormField<RegisteredAccount>(
                    isExpanded: true,
                    initialValue: _account,
                    decoration: const InputDecoration(labelText: 'Member account'),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                            value: a,
                            child: Text(a.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (a) => setState(() => _account = a),
                    validator: (a) => a == null ? 'Choose the member' : null,
                  ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _amount,
                autofocus: accounts == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount pledged (ZMW)'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || !n.isFinite || n <= 0) return 'Enter an amount';
                  if (n > pledgeMaxAmount) return 'That amount is too large';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'To be given by',
                    errorText: _dateError,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(formatDate(_due)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: pledgeNoteMaxLength,
                decoration: const InputDecoration(
                    labelText: 'What it is for (optional)',
                    hintText: 'e.g. Building fund'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
