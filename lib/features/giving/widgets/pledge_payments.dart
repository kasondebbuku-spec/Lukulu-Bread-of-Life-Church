import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pledge_providers.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/pledge.dart';
import 'pledge_dialog.dart' show pledgeMaxAmount, pledgeNoteMaxLength;

/// Asks for a payment received towards an unregistered person's pledge.
Future<PledgePayment?> showPaymentDialog(BuildContext context,
        {required double remaining}) =>
    showDialog<PledgePayment>(
      context: context,
      builder: (context) => _PaymentDialog(remaining: remaining),
    );

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.remaining});

  final double remaining;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PledgePayment(
        amount: double.parse(_amount.text.trim()),
        date: DateTime(_date.year, _date.month, _date.day),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a payment'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('payment-amount'),
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount received (ZMW)',
                  helperText: widget.remaining > 0
                      ? '${formatZmw(widget.remaining)} still to come'
                      : null,
                ),
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
                  decoration: const InputDecoration(
                    labelText: 'Date received',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: pledgeNoteMaxLength,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)', hintText: 'e.g. Cash after service'),
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

/// Lets the Finance Officer record a payment on an unregistered person's pledge.
Future<void> recordPledgePayment(
    BuildContext context, WidgetRef ref, PledgeProgress progress) async {
  final messenger = ScaffoldMessenger.of(context);
  final payment = await showPaymentDialog(context, remaining: progress.remaining);
  if (payment == null) return;
  try {
    await ref.read(pledgeRepositoryProvider).setPayments(
        progress.pledge.id, [...progress.pledge.payments, payment]);
    messenger.showSnackBar(SnackBar(
        content: Text('Recorded ${formatZmw(payment.amount)} for ${progress.pledge.memberName}.')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not record the payment. Nothing was saved.')));
  }
}

/// The payments received so far on an unregistered person's pledge, each with
/// a way to remove one entered by mistake.
Future<void> showPledgePayments(BuildContext context, String pledgeId) =>
    showDialog<void>(
      context: context,
      builder: (context) => _PaymentsListDialog(pledgeId: pledgeId),
    );

class _PaymentsListDialog extends ConsumerWidget {
  const _PaymentsListDialog({required this.pledgeId});

  final String pledgeId;

  Future<void> _remove(BuildContext context, WidgetRef ref, Pledge p, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this payment?'),
        content: Text('${formatZmw(p.payments[index].amount)} on '
            '${formatDate(p.payments[index].date)} will no longer count.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    final left = [...p.payments]..removeAt(index);
    try {
      await ref.read(pledgeRepositoryProvider).setPayments(p.id, left);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not remove the payment. Nothing was changed.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref
        .watch(allPledgeProgressProvider)
        .where((x) => x.pledge.id == pledgeId);
    final pledge = match.isEmpty ? null : match.first.pledge;
    final payments = pledge?.payments ?? const <PledgePayment>[];
    return AlertDialog(
      title: Text(pledge == null ? 'Payments' : 'Payments from ${pledge.memberName}'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: payments.isEmpty
            ? const Text('Nothing has been recorded yet.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < payments.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatZmw(payments[i].amount)),
                      subtitle: Text(payments[i].note.isEmpty
                          ? formatDate(payments[i].date)
                          : '${formatDate(payments[i].date)} • ${payments[i].note}'),
                      trailing: IconButton(
                        key: Key('remove-payment-$i'),
                        tooltip: 'Remove this payment',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(context, ref, pledge!, i),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
