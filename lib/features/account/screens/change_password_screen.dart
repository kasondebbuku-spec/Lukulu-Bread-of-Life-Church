import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/phone_login.dart';

/// Plain words for why a password could not be changed.
String changePasswordProblem(String code) => switch (code) {
      'wrong-password' ||
      'invalid-credential' ||
      'user-mismatch' =>
        'Your current password is not right. Your password has not been changed.',
      'weak-password' =>
        'That new password is too weak. Try a longer one.',
      'too-many-requests' =>
        'Too many tries. Please wait a few minutes and try again.',
      'network-request-failed' =>
        'No connection. Your password has not been changed.',
      'requires-recent-login' || 'no-current-user' =>
        'Please log out, log in again, and then change your password.',
      _ => 'Could not change your password. It has not been changed.',
    };

/// Lets a signed-in person choose a new password, after giving the current one.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authServiceProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Passwords are used exactly as typed, as they are at sign-up.
      await auth.changePassword(_current.text, _new.text);
      messenger.showSnackBar(const SnackBar(
          content: Text('Password changed. Use the new one next time you log in.')));
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = changePasswordProblem(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = changePasswordProblem(''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _box({
    required String keyName,
    required TextEditingController controller,
    required String label,
    required String autofill,
    required String? Function(String) check,
    bool last = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: TextFormField(
          key: Key(keyName),
          controller: controller,
          obscureText: !_show,
          autofillHints: [autofill],
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: last ? (_) => _save() : null,
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.lock_outline),
              errorMaxLines: 2),
          validator: (v) => check(v ?? ''),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateChangesProvider).valueOrNull?.email;
    final phone = phoneFromLoginEmail(email);
    final account = phone != null ? prettyPhone(phone) : email;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (account != null)
                        Text('For the account $account',
                            style: theme.textTheme.bodyMedium),
                      _box(
                        keyName: 'current-password',
                        controller: _current,
                        label: 'Current password',
                        autofill: AutofillHints.password,
                        check: (v) =>
                            v.isEmpty ? 'Enter your current password' : null,
                      ),
                      _box(
                        keyName: 'new-password',
                        controller: _new,
                        label: 'New password',
                        autofill: AutofillHints.newPassword,
                        check: (v) => v.length < 6
                            ? 'Use at least 6 characters'
                            : v == _current.text
                                ? 'Choose a password different from the current one'
                                : null,
                      ),
                      _box(
                        keyName: 'confirm-password',
                        controller: _confirm,
                        label: 'New password again',
                        autofill: AutofillHints.newPassword,
                        last: true,
                        check: (v) => v != _new.text
                            ? 'The two new passwords do not match'
                            : null,
                      ),
                      CheckboxListTile(
                        key: const Key('show-passwords'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Show passwords'),
                        value: _show,
                        onChanged: (v) => setState(() => _show = v ?? false),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!,
                              key: const Key('password-error'),
                              style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      FilledButton(
                        key: const Key('save-password'),
                        onPressed: _saving ? null : _save,
                        child:
                            Text(_saving ? 'Changing...' : 'Change password'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          'Forgotten your current password? Log out, then tap '
                          'Forgot password? on the log-in screen.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
