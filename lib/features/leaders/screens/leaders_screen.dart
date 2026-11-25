import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/ministry_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/ministry_position.dart';
import '../../../services/leader_directory_service.dart';
import '../widgets/ministry_position_fields.dart';

/// Church roles in the order they are listed.
const _roleOrder = <UserRole>[
  UserRole.pastor,
  UserRole.elder,
  UserRole.deacon,
  UserRole.deaconess,
  UserRole.secretariat,
  UserRole.finance,
  UserRole.hospitality,
  UserRole.oversight,
];

const _headings = <UserRole, String>{
  UserRole.pastor: 'Pastor',
  UserRole.elder: 'Elders',
  UserRole.deacon: 'Deacons',
  UserRole.deaconess: 'Deaconesses',
  UserRole.secretariat: 'Secretariat',
  UserRole.finance: 'Finance',
  UserRole.hospitality: 'Hospitality',
  UserRole.oversight: 'Financial Oversight',
};

/// Who the church's leaders are: everyone with a church role, and everyone who
/// leads in a ministry. Everyone signed in sees names and positions; phone and
/// email show only to other leaders.
class LeadersScreen extends ConsumerWidget {
  const LeadersScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(leaderDirectoryServiceProvider).rebuild();
      messenger.showSnackBar(SnackBar(
          content: Text('Directory refreshed: $n leader${n == 1 ? '' : 's'}.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not refresh the directory. Please try again.')));
    }
  }

  Future<void> _requestPosition(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final position = await showDialog<MinistryPosition>(
      context: context,
      builder: (_) => const _PositionRequestDialog(),
    );
    if (position == null) return;
    try {
      await ref.read(positionServiceProvider).request(uid, position);
      messenger.showSnackBar(SnackBar(
          content: Text('Sent. The Admin will approve ${position.label}.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not send your request. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userRoleProvider).asData?.value ?? UserAccess.member;
    final leaders = ref.watch(leadersProvider);
    final contacts = ref.watch(leaderContactsProvider).asData?.value ?? const {};
    final pending = ref.watch(myPositionRequestProvider).asData?.value;
    final theme = Theme.of(context);

    Widget person(LeaderEntry l, String subtitle) {
      final c = contacts[l.uid];
      final lines = [
        subtitle,
        if (c?.phoneText != null) c!.phoneText!,
        if ((c?.email ?? '').isNotEmpty) c!.email!,
      ];
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(l.name.isEmpty ? '?' : l.name[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary)),
        ),
        title: Text(l.name),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
      );
    }

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaders'),
        actions: [
          if (access.isAdmin)
            IconButton(
              key: const Key('refresh-directory'),
              tooltip: 'Refresh the directory from accounts',
              icon: const Icon(Icons.sync),
              onPressed: () => _refresh(context, ref),
            ),
        ],
      ),
      body: leaders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('The leaders could not be loaded.')),
        data: (all) {
          final byMinistry = <String, List<(LeaderEntry, MinistryPosition)>>{};
          for (final l in all) {
            for (final p in l.positions) {
              byMinistry.putIfAbsent(p.ministry, () => []).add((l, p));
            }
          }
          final ministryNames = byMinistry.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyState(
                      icon: Icons.groups_outlined,
                      message: 'No leaders are listed yet.'),
                ),
              for (final role in _roleOrder)
                if (all.any((l) => l.roles.contains(role))) ...[
                  heading(_headings[role] ?? role.label),
                  for (final l in all.where((l) => l.roles.contains(role)))
                    person(l, role.label),
                ],
              if (ministryNames.isNotEmpty) heading('Ministries'),
              for (final m in ministryNames) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(m,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primary)),
                ),
                for (final (l, p) in byMinistry[m]!) person(l, '${p.title}, $m'),
              ],
              const SizedBox(height: 16),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Do you lead a ministry?',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      if (pending != null)
                        Text('Your request to be ${pending.label} is waiting for '
                            'the Admin.',
                            key: const Key('position-pending'))
                      else
                        const Text(
                            'Choir, Women of Integrity, Youth and others. Ask for '
                            'your position and the Admin will approve it. Then you '
                            'can send reports to the Pastor.'),
                      if (pending == null) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          key: const Key('request-position'),
                          icon: const Icon(Icons.add),
                          label: const Text('Request my position'),
                          onPressed: () => _requestPosition(context, ref),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!access.isLeaderAccount)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                      "Leaders' phone numbers and emails are shown only to other leaders.",
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PositionRequestDialog extends StatefulWidget {
  const _PositionRequestDialog();

  @override
  State<_PositionRequestDialog> createState() => _PositionRequestDialogState();
}

class _PositionRequestDialogState extends State<_PositionRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  MinistryPosition? _position;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request my position'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: MinistryPositionFields(onChanged: (p) => _position = p),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('send-position-request'),
          onPressed: () {
            if (!_formKey.currentState!.validate() || _position == null) return;
            Navigator.pop(context, _position);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
