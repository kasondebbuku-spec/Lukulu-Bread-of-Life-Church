import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/ministry_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../models/ministry_position.dart';
import '../../../models/phone_login.dart';
import '../../../models/role_request.dart';
import 'add_staff_dialog.dart';

class RegisteredAccount {
  const RegisteredAccount(this.id, this.name, this.email, this.access,
      {this.requestedRoles = const [], this.requestedPosition});

  /// [email] is the phone number for someone who signed up with one.
  final String id, name, email;
  final UserAccess access;

  /// Roles they asked for that an Admin has not yet decided on.
  final List<UserRole> requestedRoles;

  /// A ministry position they asked for that an Admin has not yet decided on.
  final MinistryPosition? requestedPosition;
  String get label => '$name ($email)';
}

final registeredAccountsProvider =
    StreamProvider.autoDispose<List<RegisteredAccount>>((ref) {
  final access = ref.watch(userRoleProvider).value;
  if (access == null || (!access.isAdmin && !access.canManageGiving)) {
    return Stream.value([]);
  }
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .snapshots()
      .map((snapshot) {
    final accounts = snapshot.docs.map((doc) {
      final data = doc.data();
      final access = UserAccess.fromData(data);
      // Someone who signed up with a phone number has a made-up email behind the
      // scenes; show their number instead.
      final phone = data['phone'] is String && (data['phone'] as String).isNotEmpty
          ? formatPhone(data['phone'] as String)
          : null;
      final rawEmail = data['email'] as String? ?? '';
      return RegisteredAccount(doc.id, data['name'] as String? ?? 'Member',
          isPhoneLoginEmail(rawEmail) ? (phone ?? rawEmail) : rawEmail, access,
          requestedRoles: pendingRoleRequests(data, access),
          requestedPosition: MinistryPosition.fromMap(data['requestedPosition']));
    }).toList();
    accounts
        .sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return accounts;
  });
});

class AccountRolesScreen extends ConsumerWidget {
  const AccountRolesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(userRoleProvider).value?.isAdmin != true) {
      return const Scaffold(
          body: Center(child: Text('Admin access required.')));
    }
    final accounts = ref.watch(registeredAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account Roles')),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add staff account',
        onPressed: () => showDialog<void>(
            context: context, builder: (_) => const AddStaffDialog()),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add staff'),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: TextButton(
          onPressed: () => ref.invalidate(registeredAccountsProvider),
          child: const Text('Could not load accounts. Retry'),
        )),
        data: (items) => ListView(children: [
          _PendingRequests(
              accounts: items.where((a) => a.requestedRoles.isNotEmpty).toList()),
          _PendingPositions(
              accounts: items.where((a) => a.requestedPosition != null).toList()),
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Members create their own sign-in accounts. Assign more than one role when responsibilities overlap. Hospitality registers people in the church directory; Financial Oversight can view financial records without editing them.')),
          for (final account in items)
            ListTile(
              title: Text(account.label),
              subtitle: Text(account.access.label),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _RoleDialog(account: account)),
            ),
        ]),
      ),
    );
  }
}

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({required this.account});
  final RegisteredAccount account;
  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late final Set<UserRole> selected = {...widget.account.access.roles};
  late final Map<String, MinistryPosition> positions = {...widget.account.access.positions};
  bool saving = false;
  String? error;
  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final uid = ref.read(authStateChangesProvider).value?.uid;
      if (uid == widget.account.id && !selected.contains(UserRole.admin)) {
        throw StateError(
            'Keep your own Admin role. Another admin must change it.');
      }
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.account.id)
          .update({
        'roles': (selected.isEmpty ? {UserRole.member} : selected)
            .map((r) => r.name)
            .toList(),
        'positions': {for (final e in positions.entries) e.key: e.value.toMap()},
      });
      // Keep the leaders directory in step. If this fails the roles are already
      // saved; the Refresh button on the Leaders screen puts it right.
      try {
        await ref.read(leaderDirectoryServiceProvider).syncFor(widget.account.id);
      } catch (_) {}
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError
            ? e.message.toString()
            : 'Could not save roles. Please retry.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Roles for ${widget.account.name}'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in UserRole.values)
                  CheckboxListTile(
                    title: Text(role.label),
                    value: selected.contains(role),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                              if (value == true) {
                                selected.add(role);
                              } else {
                                selected.remove(role);
                              }
                            }),
                  ),
                if (positions.isNotEmpty) ...[
                  const Divider(),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Ministry positions')),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, children: [
                      for (final e in positions.entries)
                        InputChip(
                          label: Text(e.value.label),
                          onDeleted: saving
                              ? null
                              : () => setState(() => positions.remove(e.key)),
                        ),
                    ]),
                  ),
                ],
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving…' : 'Save Roles')),
        ],
      );
}

/// People who asked for a role when they signed up, awaiting one-tap approval.
class _PendingRequests extends ConsumerWidget {
  const _PendingRequests({required this.accounts});
  final List<RegisteredAccount> accounts;

  Future<void> _run(BuildContext context, Future<void> Function() action,
      String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final service = ref.read(roleRequestServiceProvider);
    // One line, and one decision, for each role a person asked for.
    final requests = [
      for (final account in accounts)
        for (final role in account.requestedRoles) (account, role),
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Waiting for your approval (${requests.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final (account, role) in requests)
              ListTile(
                key: ValueKey('request-${account.id}-${role.name}'),
                title: Text(account.label),
                subtitle: Text('Wants to be ${role.label}'
                    '${opensFinances(role) ? '\nThis opens the church\'s money records.' : ''}'),
                isThreeLine: opensFinances(role),
                trailing: Wrap(spacing: 4, children: [
                  TextButton(
                    key: Key('decline-${account.id}-${role.name}'),
                    onPressed: () => _run(
                        context,
                        () => service.decline(account.id, role),
                        'Request to be ${role.label} declined.'),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    key: Key('approve-${account.id}-${role.name}'),
                    onPressed: () => _run(
                        context,
                        () async {
                          await service.approve(account.id, role);
                          try {
                            await ref
                                .read(leaderDirectoryServiceProvider)
                                .syncFor(account.id);
                          } catch (_) {}
                        },
                        '${account.name} is now ${role.label}.'),
                    child: const Text('Approve'),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// People who asked for a place in a ministry (Choir Leader, ...), awaiting
/// one-tap approval. Approving lets them send reports to the Pastor.
class _PendingPositions extends ConsumerWidget {
  const _PendingPositions({required this.accounts});
  final List<RegisteredAccount> accounts;

  Future<void> _run(BuildContext context, Future<void> Function() action,
      String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final service = ref.read(positionServiceProvider);
    final directory = ref.read(leaderDirectoryServiceProvider);
    return Card(
      key: const Key('pending-positions'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Ministry positions waiting (${accounts.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final account in accounts)
              ListTile(
                title: Text(account.label),
                subtitle: Text('Wants to be ${account.requestedPosition!.label}'),
                trailing: Wrap(spacing: 4, children: [
                  TextButton(
                    onPressed: () => _run(
                        context,
                        () => service.decline(account.id),
                        'Request declined.'),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: () => _run(
                        context,
                        () async {
                          await service.approve(
                              account.id, account.requestedPosition!);
                          try {
                            await directory.syncFor(account.id);
                          } catch (_) {}
                        },
                        '${account.name} is now ${account.requestedPosition!.label}.'),
                    child: const Text('Approve'),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
