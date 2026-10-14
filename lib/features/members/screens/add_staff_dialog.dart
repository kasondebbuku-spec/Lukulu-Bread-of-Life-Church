import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../services/staff_account_service.dart';

/// Admin form to set up a leader, finance officer or pastor in one step.
class AddStaffDialog extends ConsumerStatefulWidget {
  const AddStaffDialog({super.key});

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<AddStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _roles = <UserRole>{};
  bool _saving = false;
  String? _error;
  String? _doneEmail;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(staffAccountServiceProvider).createStaff(
            name: _name.text,
            email: _email.text,
            roles: _roles,
          );
      if (mounted) setState(() => _doneEmail = _email.text.trim());
    } on ArgumentError catch (e) {
      _fail(e.message.toString());
    } on StaffRolesNotGranted catch (e) {
      _fail('The account for ${e.email} was created, but its roles could not be '
          'saved. Open Account Roles and set them there.');
    } on FirebaseAuthException catch (e) {
      _fail(e.code == 'email-already-in-use'
          ? 'That email is already registered. Use Account Roles to change their role.'
          : 'Could not create the account. Please try again.');
    } catch (_) {
      _fail('Could not create the account. Please try again.');
    }
  }

  void _fail(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doneEmail != null) {
      return AlertDialog(
        title: const Text('Account created'),
        content: Text('We emailed $_doneEmail a link to choose their own password. '
            'Once they have, they can sign in and will see what their role allows.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      );
    }
    return AlertDialog(
      title: const Text('Add staff account'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            Text('Roles', style: Theme.of(context).textTheme.titleSmall),
            for (final role in UserRole.values.where((r) => r != UserRole.member))
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(role.label),
                value: _roles.contains(role),
                onChanged: _saving
                    ? null
                    : (on) => setState(() {
                          if (on == true) {
                            _roles.add(role);
                          } else {
                            _roles.remove(role);
                          }
                        }),
              ),
            const SizedBox(height: 4),
            Text(
              'You will not see or set a password. They get an email to choose their own.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _create,
            child: Text(_saving ? 'Creating…' : 'Create account')),
      ],
    );
  }
}
