import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/user_role_provider.dart';

class RegisteredAccount {
  const RegisteredAccount(this.id, this.name, this.email, this.access);
  final String id, name, email;
  final UserAccess access;
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
      return RegisteredAccount(doc.id, data['name'] as String? ?? 'Member',
          data['email'] as String? ?? '', UserAccess.fromData(data));
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
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: TextButton(
          onPressed: () => ref.invalidate(registeredAccountsProvider),
          child: const Text('Could not load accounts. Retry'),
        )),
        data: (items) => ListView(children: [
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
      });
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
