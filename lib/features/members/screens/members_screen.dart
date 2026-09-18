import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/async_value_extensions.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/member.dart';
import '../../../repositories/repository_providers.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _editingDocId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    final member = Member(
      id: _editingDocId ?? '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    final repo = ref.read(membersRepositoryProvider);
    if (_editingDocId == null) {
      await repo.add(member);
    } else {
      await repo.update(_editingDocId!, member);
    }

    if (!mounted) return;
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _editingDocId = null;
    Navigator.pop(context);
  }

  void _showMemberDialog({Member? member}) {
    if (member != null) {
      _nameController.text = member.name;
      _emailController.text = member.email;
      _phoneController.text = member.phone;
      _editingDocId = member.id;
    } else {
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _editingDocId = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_editingDocId == null ? 'Add Member' : 'Edit Member'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) => (val != null && val.contains('@'))
                    ? null
                    : 'Invalid email',
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: _saveMember, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _deleteMember(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'member')) return;
    await ref.read(membersRepositoryProvider).delete(docId);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(userRoleProvider).canManageMembers;
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Members Directory')),
      body: AsyncValueView<List<Member>>(
        value: membersAsync,
        data: (members) {
          if (members.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              message: 'No members yet.\nAdd your first member with the + button.',
            );
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(member.name),
                  subtitle: Text('${member.email}\n${member.phone}'),
                  isThreeLine: true,
                  trailing: canEdit
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showMemberDialog(member: member),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteMember(member.id),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showMemberDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
