import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/church_event.dart';
import '../../../repositories/repository_providers.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
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

  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final event = ChurchEvent(
      id: '',
      title: _titleController.text.trim(),
      date: _selectedDate,
      location: _locationController.text.trim(),
    );
    await ref.read(eventsRepositoryProvider).add(event);

    if (!mounted) return;
    _titleController.clear();
    _locationController.clear();
    _selectedDate = DateTime.now();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Event'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Event Title'),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatDate(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(setDialogState),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration:
                      const InputDecoration(labelText: 'Location (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(onPressed: _addEvent, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'event')) return;
    await ref.read(eventsRepositoryProvider).delete(docId);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canManageEvents,
          orElse: () => false,
        );
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Events')),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_busy_outlined,
              message: 'No events yet.\nUpcoming services and gatherings will appear here.',
            );
          }

          final today = DateTime.now();
          final startOfToday = DateTime(today.year, today.month, today.day);
          final upcoming = events.where((e) => !e.date.isBefore(startOfToday)).toList();
          final past = events.where((e) => e.date.isBefore(startOfToday)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text('No upcoming events scheduled.'),
                )
              else
                ...upcoming.map((e) => _EventCard(
                      event: e,
                      isPast: false,
                      canEdit: canEdit,
                      onDelete: () => _deleteEvent(e.id),
                    )),
              if (past.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('Past Events',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ),
                ...past.map((e) => _EventCard(
                      event: e,
                      isPast: true,
                      canEdit: canEdit,
                      onDelete: () => _deleteEvent(e.id),
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

const _monthAbbrev = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isPast,
    required this.canEdit,
    required this.onDelete,
  });

  final ChurchEvent event;
  final bool isPast;
  final bool canEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = isPast ? AppColors.textSecondary : AppColors.primary;

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(_monthAbbrev[event.date.month - 1],
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('${event.date.day}',
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(formatDate(event.date),
                        style: Theme.of(context).textTheme.bodySmall),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(event.location,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
