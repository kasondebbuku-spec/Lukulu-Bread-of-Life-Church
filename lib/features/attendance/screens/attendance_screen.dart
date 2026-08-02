import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_role_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/attendance_record.dart';
import '../../../repositories/repository_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController();
  final _newVisitorsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _countController.dispose();
    _newVisitorsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(StateSetter setDialogState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setDialogState(() => _selectedDate = picked);
    }
  }

  Future<void> _addAttendance() async {
    if (!_formKey.currentState!.validate()) return;

    final record = AttendanceRecord(
      id: '',
      date: _selectedDate,
      count: int.parse(_countController.text.trim()),
      newVisitors: int.parse(_newVisitorsController.text.trim()),
    );
    await ref.read(attendanceRepositoryProvider).add(record);

    if (!mounted) return;
    _countController.clear();
    _newVisitorsController.clear();
    _selectedDate = DateTime.now();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Attendance Record'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatDate(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(setDialogState),
                ),
                TextFormField(
                  controller: _countController,
                  decoration: const InputDecoration(labelText: 'Total Attendance'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      int.tryParse((val ?? '').trim()) == null ? 'Enter a number' : null,
                ),
                TextFormField(
                  controller: _newVisitorsController,
                  decoration: const InputDecoration(labelText: 'New Visitors'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      int.tryParse((val ?? '').trim()) == null ? 'Enter a number' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(onPressed: _addAttendance, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAttendance(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'attendance record')) return;
    await ref.read(attendanceRepositoryProvider).delete(docId);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canManageAttendance,
          orElse: () => false,
        );
    final recordsAsync = ref.watch(attendanceRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Tracker')),
      body: recordsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.how_to_reg_outlined,
              message: 'No attendance records yet.\nLog a service to get started.',
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final record = docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.how_to_reg)),
                  title: Text(formatDate(record.date)),
                  subtitle: Text(
                      'Attended: ${record.count}  •  New: ${record.newVisitors}'),
                  trailing: canEdit
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAttendance(record.id))
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _showAddDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}
