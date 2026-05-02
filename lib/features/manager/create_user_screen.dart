import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.worker;
  bool _busy = false;
  bool _showPwd = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(usersRepositoryProvider).createUserByManager(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            role: _role,
          );
      ref.invalidate(usersByRoleProvider(UserRole.worker));
      ref.invalidate(usersByRoleProvider(UserRole.qa));
      if (!mounted) return;
      setState(() {
        _info = 'Account created successfully.';
        _password.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    final msg = raw.toLowerCase();
    if (msg.contains('user already registered') || msg.contains('already exists')) {
      return 'This email is already registered.';
    }
    if (msg.contains('unauthorized') || msg.contains('forbidden')) {
      return 'Only manager/admin can create accounts.';
    }
    if (msg.contains('password')) {
      return 'Password must meet Supabase requirements (minimum 6 characters).';
    }
    if (msg.contains('functions')) {
      return 'Account service unavailable. Deploy Supabase function: manager-create-user.';
    }
    return 'Failed to create account: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New worker/QA account',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPwd,
                        decoration: InputDecoration(
                          labelText: 'Temporary password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showPwd = !_showPwd),
                            icon: Icon(
                              _showPwd
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.worker,
                            child: Text('Worker'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.qa,
                            child: Text('Quality Assurance'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? _role),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: cs.error)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _info!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(_busy ? 'Creating...' : 'Create account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

