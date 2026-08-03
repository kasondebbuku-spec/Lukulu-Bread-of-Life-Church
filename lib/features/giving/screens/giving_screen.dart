import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/giving_record.dart';
import '../../../repositories/repository_providers.dart';

String formatZmw(double value) => 'ZMW ${value.toStringAsFixed(2)}';

class GivingScreen extends ConsumerStatefulWidget {
  const GivingScreen({super.key});

  @override
  ConsumerState<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends ConsumerState<GivingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _memberNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addGiving() async {
    if (!_formKey.currentState!.validate()) return;

    final record = GivingRecord(
      id: '',
      memberName: _memberNameController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      date: DateTime.now(),
    );
    await ref.read(givingRepositoryProvider).add(record);

    if (!mounted) return;
    _memberNameController.clear();
    _amountController.clear();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Contribution'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _memberNameController,
                decoration: const InputDecoration(labelText: 'Member Name'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (ZMW)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  final amount = double.tryParse((val ?? '').trim());
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: _addGiving, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _deleteGiving(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'giving record')) return;
    await ref.read(givingRepositoryProvider).delete(docId);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canManageGiving,
          orElse: () => false,
        );
    final recordsAsync = ref.watch(givingRecordsProvider);
    final totalThisMonth = ref.watch(givingTotalThisMonthProvider);
    final totalAllTime = ref.watch(givingTotalAllTimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Giving & Tithes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _TotalCard(label: 'This Month', value: totalThisMonth),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalCard(label: 'All Time', value: totalAllTime),
                ),
              ],
            ),
          ),
          Expanded(
            child: recordsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    message: 'No giving records yet.\nRecorded contributions will appear here.',
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final record = docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondaryDark.withValues(alpha: 0.12),
                          child: const Icon(Icons.savings_outlined, color: AppColors.secondaryDark),
                        ),
                        title: Text(record.memberName),
                        subtitle: Text(
                            '${formatZmw(record.amount)} • ${formatDate(record.date)}'),
                        trailing: canEdit
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteGiving(record.id))
                            : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _showAddDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.secondaryDark, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, size: 14, color: AppColors.secondaryDark),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatZmw(value),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryDark,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
