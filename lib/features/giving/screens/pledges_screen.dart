import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audit_actor_provider.dart';
import '../../../core/providers/pledge_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/pledge.dart';
import '../../members/screens/account_roles_screen.dart';
import '../widgets/my_pledges_section.dart';
import '../widgets/pledge_card.dart';
import '../widgets/pledge_dialog.dart';

/// Everyone's pledges, for those who may see giving: who has pledged, how much
/// has been given, and what is overdue. The Finance Officer can also record a
/// pledge for a member who cannot do it themselves.
class PledgesScreen extends ConsumerWidget {
  const PledgesScreen({super.key});

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final actor = ref.read(auditActorProvider);
    List<RegisteredAccount> accounts;
    try {
      accounts = await ref.read(registeredAccountsProvider.future);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not load member accounts. Please try again.')));
      return;
    }
    if (!context.mounted) return;
    final draft = await showPledgeDialog(context, accounts: accounts);
    final account = draft?.account;
    if (draft == null || account == null) return;
    final today = DateTime.now();
    try {
      await ref.read(pledgeRepositoryProvider).add(Pledge(
            id: '',
            userId: account.id,
            memberName: account.name,
            amount: draft.amount,
            madeOn: DateTime(today.year, today.month, today.day),
            dueDate: draft.dueDate,
            note: draft.note,
            createdBy: actor?.name ?? '',
          ));
      messenger.showSnackBar(
          SnackBar(content: Text('Pledge recorded for ${account.name}.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not record the pledge. Please try again.')));
    }
  }

  Future<void> _change(BuildContext context, WidgetRef ref, Pledge p) async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showPledgeDialog(context, existing: p);
    if (draft == null) return;
    try {
      await ref.read(pledgeRepositoryProvider).change(p.id,
          amount: draft.amount, dueDate: draft.dueDate, note: draft.note);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not change the pledge. Please try again.')));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Pledge p) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmCancelPledge(context)) return;
    try {
      await ref.read(pledgeRepositoryProvider).cancel(p.id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not cancel the pledge. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRecord = ref.watch(userRoleProvider).value?.canManageGiving == true;
    final theme = Theme.of(context);
    final all = ref.watch(allPledgeProgressProvider);
    final open = all.where((p) => p.state != PledgeState.cancelled).toList();
    final outstanding = open.fold(0.0, (s, p) => s + p.remaining);
    final overdue = open.where((p) => p.state == PledgeState.overdue).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Pledges')),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              key: const Key('record-pledge'),
              onPressed: () => _record(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Record a pledge'),
            )
          : null,
      body: open.isEmpty
          ? const EmptyState(
              icon: Icons.handshake_outlined,
              message: 'No pledges yet.\nMembers can add their own from My Giving.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${open.length} pledge${open.length == 1 ? '' : 's'}',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Still to be given: ${formatZmw(outstanding)}'),
                        Text(overdue == 0 ? 'None overdue' : '$overdue overdue'),
                      ],
                    ),
                  ),
                ),
                for (final p in open)
                  PledgeCard(
                    progress: p,
                    showMember: true,
                    onChange: canRecord ? () => _change(context, ref, p.pledge) : null,
                    onCancel: canRecord ? () => _cancel(context, ref, p.pledge) : null,
                  ),
              ],
            ),
    );
  }
}
