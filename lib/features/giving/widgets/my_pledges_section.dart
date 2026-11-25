import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/pledge_providers.dart';
import '../../../models/pledge.dart';
import 'pledge_card.dart';
import 'pledge_dialog.dart';

/// Asks before cancelling a pledge. Cancelling keeps the record (it just stops
/// counting and stops reminding).
Future<bool> confirmCancelPledge(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel this pledge?'),
      content: const Text('It will stop counting and you will no longer be reminded about it.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel pledge')),
      ],
    ),
  );
  return yes ?? false;
}

/// "My Pledges" on My Giving: the member's own pledges with what they have
/// given towards each, and a way to make, change or cancel one.
class MyPledgesSection extends ConsumerWidget {
  const MyPledgesSection({super.key});

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.read(currentUserIdProvider);
    final name = ref.read(displayNameProvider);
    if (uid == null) return;
    final draft = await showPledgeDialog(context);
    if (draft == null) return;
    final today = DateTime.now();
    try {
      await ref.read(pledgeRepositoryProvider).add(Pledge(
            id: '',
            userId: uid,
            memberName: name,
            amount: draft.amount,
            madeOn: DateTime(today.year, today.month, today.day),
            dueDate: draft.dueDate,
            note: draft.note,
            createdBy: name,
          ));
      messenger.showSnackBar(const SnackBar(content: Text('Pledge recorded.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not record your pledge. Please try again.')));
    }
  }

  Future<void> _change(BuildContext context, WidgetRef ref, Pledge p) async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showPledgeDialog(context, existing: p);
    if (draft == null) return;
    try {
      await ref.read(pledgeRepositoryProvider).change(p.id,
          amount: draft.amount, dueDate: draft.dueDate, note: draft.note);
      messenger.showSnackBar(const SnackBar(content: Text('Pledge updated.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not change your pledge. Please try again.')));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Pledge p) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmCancelPledge(context)) return;
    try {
      await ref.read(pledgeRepositoryProvider).cancel(p.id);
      messenger.showSnackBar(const SnackBar(content: Text('Pledge cancelled.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not cancel your pledge. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loaded = ref.watch(myPledgesProvider);
    final shown = ref
        .watch(myPledgeProgressProvider)
        .where((p) => p.state != PledgeState.cancelled)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('My Pledges', style: theme.textTheme.titleLarge)),
            FilledButton.tonalIcon(
              key: const Key('new-pledge'),
              icon: const Icon(Icons.add),
              label: const Text('New pledge'),
              onPressed: () => _new(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loaded.isLoading && shown.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()))
        else if (loaded.hasError)
          const Text('Your pledges could not be loaded.')
        else if (shown.isEmpty)
          const Text('You have no pledges yet. Tap New pledge to record one.')
        else ...[
          for (final p in shown)
            PledgeCard(
              progress: p,
              onChange: () => _change(context, ref, p.pledge),
              onCancel: () => _cancel(context, ref, p.pledge),
            ),
          Text('Giving recorded in your name as a Pledge counts towards your pledges automatically.',
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
