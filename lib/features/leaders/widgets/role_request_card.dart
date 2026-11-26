import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../models/role_request.dart';
import 'role_chips.dart';

/// On the Leaders screen: ask for another church role without signing up again.
/// An Admin approves each one.
class RoleRequestCard extends ConsumerWidget {
  const RoleRequestCard({super.key});

  Future<void> _ask(
      BuildContext context, WidgetRef ref, List<UserRole> available) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final chosen = await showDialog<Set<UserRole>>(
      context: context,
      builder: (_) => _AskDialog(available: available),
    );
    if (chosen == null || chosen.isEmpty) return;
    final words = inWords([
      for (final r in requestableRoles)
        if (chosen.contains(r)) r.label,
    ]);
    try {
      await ref.read(roleRequestServiceProvider).ask(uid, chosen);
      messenger.showSnackBar(
          SnackBar(content: Text('Sent. The Admin will approve $words.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not send your request. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userRoleProvider).asData?.value ?? UserAccess.member;
    final waiting = ref.watch(ownPendingRoleRequestsProvider);
    final available = [
      for (final r in requestableRoles)
        if (!access.roles.contains(r) && !waiting.contains(r)) r,
    ];
    final theme = Theme.of(context);

    return Card(
      key: const Key('role-request-card'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you serve in another church role?',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Elder, Finance, Secretariat and others. You can hold several, and '
                'you see everything for all of them at once. The Admin approves each.'),
            if (waiting.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Waiting for the Admin: ${inWords([for (final r in waiting) r.label])}.',
                    key: const Key('roles-waiting'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            if (available.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const Key('request-role'),
                icon: const Icon(Icons.add),
                label: const Text('Ask for a role'),
                onPressed: () => _ask(context, ref, available),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AskDialog extends StatefulWidget {
  const _AskDialog({required this.available});

  final List<UserRole> available;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _chosen = <UserRole>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask for a role'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: RoleChips(
          roles: widget.available,
          selected: _chosen,
          onChanged: (role, on) =>
              setState(() => on ? _chosen.add(role) : _chosen.remove(role)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('send-role-request'),
          onPressed:
              _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
