import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/giving_record.dart';
import '../../../repositories/repository_providers.dart';
import '../zmw_denominations.dart';
import 'income_forms_list_screen.dart';
import 'sunday_income_form_screen.dart';
import 'weekly_statement_screen.dart';

String formatZmw(double value) => 'ZMW ${value.toStringAsFixed(2)}';

Color categoryColor(GivingCategory category) {
  switch (category) {
    case GivingCategory.tithe:
      return AppColors.secondaryDark;
    case GivingCategory.offering:
      return AppColors.blue;
    case GivingCategory.seed:
      return AppColors.primaryLight;
    case GivingCategory.thanksgiving:
      return AppColors.blueLight;
    case GivingCategory.pledge:
      return AppColors.secondary;
  }
}

class GivingScreen extends ConsumerStatefulWidget {
  const GivingScreen({super.key});

  @override
  ConsumerState<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends ConsumerState<GivingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNameController = TextEditingController();
  final _amountController = TextEditingController();
  GivingCategory _selectedCategory = GivingCategory.tithe;

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
      category: _selectedCategory,
    );
    await ref.read(givingRepositoryProvider).add(record);

    if (!mounted) return;
    _memberNameController.clear();
    _amountController.clear();
    Navigator.pop(context);
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt, color: AppColors.primary),
              title: const Text('Record Contribution'),
              subtitle: const Text('Named tithe, offering, or special gift'),
              onTap: () {
                Navigator.pop(context);
                _showAddDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.blue),
              title: const Text('Sunday Income Form'),
              subtitle: const Text('Full cash count, forex, cheques & attendance'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SundayIncomeFormScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    _selectedCategory = GivingCategory.tithe;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                const SizedBox(height: 12),
                DropdownButtonFormField<GivingCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: GivingCategory.tithe, child: Text('Tithe')),
                    DropdownMenuItem(
                        value: GivingCategory.offering, child: Text('Offering')),
                    DropdownMenuItem(value: GivingCategory.seed, child: Text('Seed')),
                    DropdownMenuItem(
                        value: GivingCategory.thanksgiving, child: Text('Thanksgiving')),
                    DropdownMenuItem(value: GivingCategory.pledge, child: Text('Pledge')),
                  ],
                  onChanged: (v) => setDialogState(() => _selectedCategory = v!),
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
      appBar: AppBar(
        title: const Text('Giving & Tithes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'Weekly Statement',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WeeklyStatementScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Sunday Income Forms',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const IncomeFormsListScreen()),
            ),
          ),
        ],
      ),
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
                    final trailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (record.category != null)
                          TagChip(
                            label: record.category!.label,
                            color: categoryColor(record.category!),
                          ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteGiving(record.id),
                          ),
                      ],
                    );

                    if (record.denominationBreakdown != null) {
                      final nonZero = record.denominationBreakdown!.entries
                          .where((e) => e.value > 0)
                          .toList();
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.blue.withValues(alpha: 0.12),
                            child: const Icon(Icons.savings_outlined, color: AppColors.blue),
                          ),
                          title: Text(record.memberName),
                          subtitle: Text(
                              '${formatZmw(record.amount)} • ${formatDate(record.date)}'),
                          trailing: trailing,
                          children: nonZero.map((e) {
                            final denom = zmwDenominations
                                .firstWhere((d) => d.key == e.key);
                            return ListTile(
                              dense: true,
                              title: Text('${denom.label} × ${e.value}'),
                              trailing: Text(formatZmw(denom.value * e.value)),
                            );
                          }).toList(),
                        ),
                      );
                    }

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
                        trailing: trailing,
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
              onPressed: _showAddMenu, child: const Icon(Icons.add))
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
