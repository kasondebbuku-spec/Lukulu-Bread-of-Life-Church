import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/async_value_extensions.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../members/screens/account_roles_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/giving_record.dart';
import '../../../repositories/repository_providers.dart';
import '../giving_theme.dart';
import '../zmw_denominations.dart';
import 'income_forms_list_screen.dart';
import 'sunday_income_form_screen.dart';
import 'weekly_statement_screen.dart';

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
  RegisteredAccount? _selectedAccount;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _memberNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addGiving(StateSetter setDialogState) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setDialogState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final record = GivingRecord(
        id: '',
        memberName: _memberNameController.text.trim(),
        memberUserId: _selectedAccount?.id,
        recordedBy: ref.read(authStateChangesProvider).value!.uid,
        amount: double.parse(_amountController.text.trim()),
        date: DateTime.now(),
        category: _selectedCategory,
      );
      await ref.read(givingRepositoryProvider).add(record);

      if (!mounted) return;
      _memberNameController.clear();
      _amountController.clear();
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setDialogState(() {
          _saving = false;
          _saveError = 'Contribution was not saved. Please retry.';
        });
      }
    } finally {
      _saving = false;
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.person_add_alt, color: AppColors.primary),
              title: const Text('Record Contribution'),
              subtitle: const Text('Named tithe, offering, or special gift'),
              onTap: () {
                Navigator.pop(context);
                _showAddDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.blue),
              title: const Text('Sunday Income Form'),
              subtitle:
                  const Text('Full cash count, forex, cheques & attendance'),
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

  Future<void> _showAddDialog() async {
    _selectedCategory = GivingCategory.tithe;
    _selectedAccount = null;
    _saveError = null;
    _memberNameController.clear();
    _amountController.clear();
    List<RegisteredAccount> accounts;
    try {
      accounts = await ref.read(registeredAccountsProvider.future);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load member accounts. Please retry.')));
      }
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Contribution'),
          content: SingleChildScrollView(
              child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Link to member account'),
                  items: [
                    const DropdownMenuItem(
                        value: '',
                        child: Text('Unlinked / visitor contribution')),
                    for (final account in accounts)
                      DropdownMenuItem(
                          value: account.id,
                          child: Text(account.label,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _saving
                      ? null
                      : (id) => setDialogState(() {
                            _selectedAccount = id == null || id.isEmpty
                                ? null
                                : accounts.firstWhere((a) => a.id == id);
                            _memberNameController.text =
                                _selectedAccount?.name ?? '';
                          }),
                ),
                const Text(
                    'Choose the correct email address. Only that account can see this contribution in My Giving. Unlinked entries remain private to Finance.'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _memberNameController,
                  readOnly: _selectedAccount != null || _saving,
                  decoration: const InputDecoration(labelText: 'Member Name'),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount (ZMW)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    final amount = double.tryParse((val ?? '').trim());
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GivingCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                        value: GivingCategory.tithe, child: Text('Tithe')),
                    DropdownMenuItem(
                        value: GivingCategory.offering,
                        child: Text('Offering')),
                    DropdownMenuItem(
                        value: GivingCategory.seed, child: Text('Seed')),
                    DropdownMenuItem(
                        value: GivingCategory.thanksgiving,
                        child: Text('Thanksgiving')),
                    DropdownMenuItem(
                        value: GivingCategory.pledge, child: Text('Pledge')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => _selectedCategory = v!),
                ),
                if (_saveError != null)
                  Text(_saveError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ),
          )),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: _saving ? null : () => _addGiving(setDialogState),
                child: Text(_saving ? 'Saving…' : 'Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGiving(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'giving record')) return;
    await ref.read(givingRepositoryProvider).delete(docId);
  }

  Future<void> _linkContribution(GivingRecord record) async {
    try {
      final accounts = await ref.read(registeredAccountsProvider.future);
      if (!mounted) return;
      final accountId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
                title: Text(
                    'Link ${record.memberName} — ${record.currency} ${record.amount.toStringAsFixed(2)}'),
                children: [
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'Choose the verified contributor account. This shares this individual entry with that member. Do not link a service total or pooled offering to one person.')),
                  for (final account in accounts)
                    SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, account.id),
                        child: Text(account.label)),
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                ],
              ));
      if (accountId == null) return;
      final account = accounts.firstWhere((a) => a.id == accountId);
      final firestore = ref.read(firestoreProvider);
      final uid = ref.read(authStateChangesProvider).value!.uid;
      final document = firestore.collection('giving').doc(record.id);
      await firestore.runTransaction((transaction) async {
        final current = await transaction.get(document);
        if (!current.exists || current.data()?['memberUserId'] != null) {
          throw StateError('This record has already been linked or removed.');
        }
        transaction.update(document, {
          'memberUserId': account.id,
          'linkedBy': uid,
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Linked to ${account.label}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not link the contribution. Refresh and try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(userRoleProvider).value?.canViewGiving != true) {
      return const Scaffold(
          body: Center(child: Text('Financial access required.')));
    }
    final canEdit = ref.watch(userRoleProvider).canManageGiving;
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
              MaterialPageRoute(
                  builder: (context) => const WeeklyStatementScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Sunday Income Forms',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const IncomeFormsListScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          recordsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Totals unavailable until records load.')),
            data: (records) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _TotalCard(
                        label: 'This Month (ZMW)', value: totalThisMonth),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TotalCard(
                        label: 'All Time (ZMW)', value: totalAllTime),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<GivingRecord>>(
              value: recordsAsync,
              data: (docs) {
                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    message:
                        'No giving records yet.\nRecorded contributions will appear here.',
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final record = docs[index];
                    final trailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit &&
                            record.memberUserId == null &&
                            record.denominationBreakdown == null)
                          IconButton(
                              icon: const Icon(Icons.link),
                              tooltip:
                                  'Link individual contribution to account',
                              onPressed: () => _linkContribution(record)),
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
                            backgroundColor:
                                AppColors.blue.withValues(alpha: 0.12),
                            child: const Icon(Icons.savings_outlined,
                                color: AppColors.blue),
                          ),
                          title: Text(record.memberName),
                          subtitle: Text(
                              '${record.currency} ${record.amount.toStringAsFixed(2)} • ${formatDate(record.date)}'),
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
                          backgroundColor:
                              AppColors.secondaryDark.withValues(alpha: 0.12),
                          child: const Icon(Icons.savings_outlined,
                              color: AppColors.secondaryDark),
                        ),
                        title: Text(record.memberName),
                        subtitle: Text(
                            '${record.currency} ${record.amount.toStringAsFixed(2)} • ${formatDate(record.date)}'),
                        trailing: trailing,
                      ),
                    );
                  },
                );
              },
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
          border: Border(
              left: BorderSide(color: AppColors.secondaryDark, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 14, color: AppColors.secondaryDark),
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
