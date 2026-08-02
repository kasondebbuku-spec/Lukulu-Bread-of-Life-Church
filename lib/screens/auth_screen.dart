import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key}); // keep const constructor

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _email = '', _password = '', _name = '', _role = 'member';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);
    try {
      if (_isLogin) {
        await _auth.signIn(_email, _password);
      } else {
        await _auth.signUp(_email, _password, _name, _role);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLogin ? 'Logged in!' : 'Account created!')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed (${e.code})')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            colors: [AppColors.primaryDark, AppColors.primary],
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
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.church, color: AppColors.secondary, size: 40),
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
                                onSaved: (val) => _name = val!,
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (val) => _email = val!,
                              validator: (val) =>
                                  (val != null && val.contains('@')) ? null : 'Invalid email',
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
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              onSaved: (val) => _password = val!,
                              validator: (val) =>
                                  (val != null && val.length >= 6) ? null : 'Min 6 chars',
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                initialValue: _role,
                                items: const [
                                  DropdownMenuItem(value: 'member', child: Text('Member')),
                                  DropdownMenuItem(value: 'deacon', child: Text('Deacon')),
                                  DropdownMenuItem(
                                      value: 'deaconess', child: Text('Deaconess')),
                                  DropdownMenuItem(value: 'elder', child: Text('Elder')),
                                  DropdownMenuItem(value: 'pastor', child: Text('Pastor')),
                                  DropdownMenuItem(
                                      value: 'finance', child: Text('Finance Officer')),
                                  DropdownMenuItem(
                                      value: 'secretariat', child: Text('Secretariat')),
                                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                ],
                                onChanged: (val) => setState(() => _role = val!),
                                onSaved: (val) => _role = val!,
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
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
