import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/providers/auth_providers.dart';
import '../core/providers/user_role_provider.dart';
import '../features/leaders/widgets/ministry_position_fields.dart';
import '../features/leaders/widgets/role_chips.dart';
import '../models/ministry_position.dart';
import '../models/phone_login.dart';
import '../models/role_request.dart';
import '../core/theme/app_theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  String _email = '', _password = '', _name = '';

  /// Church roles asked for at sign-up; a person may serve in several.
  final Set<UserRole> _requestedRoles = {};

  /// Signing in or up with a phone number instead of an email.
  bool _usePhone = false;

  /// Asking for a place in a ministry (Choir Leader, ...) at sign-up.
  bool _leadsMinistry = false;
  MinistryPosition? _position;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_isLogin) {
        await auth.signIn(_email, _password);
      } else {
        // A number in the box means a phone account, whichever keypad was used.
        final phone = looksLikePhone(_email) ? normalizePhone(_email) : null;
        await auth.signUp(_email, _password, _name,
            requestedRoles: {..._requestedRoles},
            phone: phone,
            requestedPosition: _leadsMinistry ? _position : null);
      }
      if (!mounted) return;
      final asked = [
        ..._roleWords(),
        if (_leadsMinistry && _position != null) _position!.label,
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isLogin
                ? 'Logged in!'
                : asked.isEmpty
                    ? 'Account created!'
                    : 'Account created! Your request to be ${inWords(asked)} '
                        'has been sent to the Admin.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to sign in right now. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// The ticked roles' names, in a fixed order.
  List<String> _roleWords() => [
        for (final r in requestableRoles)
          if (_requestedRoles.contains(r)) r.label,
      ];

  /// Under the box while a number is typed: how the app will read it.
  String? _phoneHelper(String text) {
    if (!isPhoneAttempt(text)) return null;
    final digits = normalizePhone(text);
    return digits == null
        ? 'For example 0971234567 or +260971234567'
        : 'Phone number: ${prettyPhone(digits)}';
  }

  /// An email or a phone number is accepted in the same box.
  String? _checkEntry(String text) {
    if (isPhoneAttempt(text)) {
      return normalizePhone(text) != null ? null : phoneProblem(text);
    }
    if (_usePhone) return 'Enter a valid phone number';
    return text.contains('@') ? null : 'Enter your email or phone number';
  }

  /// A plain-words message for a failed sign-in or sign-up. Phone accounts are
  /// told about the phone number, never the made-up address behind it.
  String _authMessage(FirebaseAuthException e) {
    final phone = _usePhone || looksLikePhone(_email);
    if (phone) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'That phone number already has an account. Try logging in.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'That phone number and password do not match an account. If you '
              'first signed up with an email, log in with that email. New to the '
              'app? Tap Sign up.';
        case 'invalid-email':
          return 'That phone number does not look right.';
      }
    }
    return e.message ?? 'Authentication failed (${e.code})';
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || email.isEmpty || !mounted) return;

    if (looksLikePhone(email)) {
      // A phone account has no real email, so there is nowhere to send a link.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone number accounts'),
          content: const Text(
              'A reset link cannot be sent to a phone number. Please ask the '
              'Admin to help you sign up again.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('If an account exists for $email, a reset link is on its way.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == 'invalid-email'
              ? 'That email address does not look right.'
              : 'Could not send the reset link. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.blueDark
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/bol_logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bread of Life',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    'Lukulu Branch',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 12,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? 'Welcome Back' : 'Create Account',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 20),
                            if (!_isLogin) ...[
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                onSaved: (val) => _name = val!.trim(),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _emailController,
                              builder: (context, value, _) => TextFormField(
                              key: Key(_usePhone ? 'phone-field' : 'email-field'),
                              decoration: InputDecoration(
                                labelText: _usePhone
                                    ? 'Phone number'
                                    : 'Email or phone number',
                                hintText: _usePhone ? 'e.g. 097 123 4567' : null,
                                helperText: _phoneHelper(value.text),
                                helperMaxLines: 2,
                                errorMaxLines: 3,
                                prefixIcon: Icon(
                                    _usePhone || isPhoneAttempt(value.text)
                                        ? Icons.phone_outlined
                                        : Icons.email_outlined),
                              ),
                              inputFormatters: const [_SignInEntryFormatter()],
                              controller: _emailController,
                              keyboardType: _usePhone
                                  ? TextInputType.phone
                                  : TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: [
                                _usePhone
                                    ? AutofillHints.telephoneNumber
                                    : AutofillHints.email,
                              ],
                              onSaved: (val) => _email = val!.trim(),
                              validator: (val) => _checkEntry(val ?? ''),
                            ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                key: const Key('toggle-phone'),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(() {
                                          _usePhone = !_usePhone;
                                          _emailController.clear();
                                        }),
                                child: Text(_usePhone
                                    ? 'Use an email instead'
                                    : 'No email? Use your phone number'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: [
                                _isLogin
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              onSaved: (val) => _password = val!,
                              validator: (val) =>
                                  (val != null && val.length >= 6)
                                      ? null
                                      : 'Min 6 chars',
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              Text('Do you serve as a leader? Tick all that apply.',
                                  style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                              RoleChips(
                                roles: requestableRoles,
                                selected: _requestedRoles,
                                enabled: !_isSubmitting,
                                onChanged: (role, on) => setState(() => on
                                    ? _requestedRoles.add(role)
                                    : _requestedRoles.remove(role)),
                              ),
                              const SizedBox(height: 6),
                              CheckboxListTile(
                                key: const Key('leads-ministry'),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: const Text(
                                    'I lead a ministry (Choir, Women of Integrity...)'),
                                value: _leadsMinistry,
                                onChanged: _isSubmitting
                                    ? null
                                    : (v) => setState(() {
                                          _leadsMinistry = v ?? false;
                                          if (!_leadsMinistry) _position = null;
                                        }),
                              ),
                              if (_leadsMinistry)
                                MinistryPositionFields(
                                    onChanged: (p) => _position = p),
                            ],
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isSubmitting ? null : _forgotPassword,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 8),
                              Text(
                                _requestedRoles.isEmpty
                                    ? 'You will join as a Member.'
                                    : 'You can use the app as a Member now. The Admin '
                                        'will approve your ${inWords(_roleWords())} '
                                        'access.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : Text(_isLogin ? 'Login' : 'Sign Up'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(() => _isLogin = !_isLogin),
                              child: Text(_isLogin
                                  ? "Need an account? Sign up"
                                  : 'Already have an account? Login'),
                            ),
                          ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tidies the sign-in box as you type or paste: a Zambian number is spaced the
/// way the app reads it, and copied-in oddities are dropped. It only reformats
/// while you are typing at the end, so editing in the middle is left alone.
class _SignInEntryFormatter extends TextInputFormatter {
  const _SignInEntryFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final atEnd = newValue.selection.baseOffset >= newValue.text.length;
    if (!atEnd) return newValue;
    final text = formatSignInEntry(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Enter your account email and we'll send a reset link."),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email or phone number'),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('Send link')),
      ],
    );
  }
}
