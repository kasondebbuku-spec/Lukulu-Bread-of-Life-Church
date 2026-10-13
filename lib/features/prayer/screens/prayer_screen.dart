import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/prayer_request.dart';
import '../../../repositories/repository_providers.dart';

/// Longest prayer point accepted (also enforced by the server rules).
const prayerRequestMaxLength = 1000;

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  void _say(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addPrayerRequest() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _PrayerDialog(
        title: 'Prayer Request',
        submitLabel: 'Submit',
      ),
    );
    if (text == null || !mounted) return;

    try {
      await ref.read(prayerRepositoryProvider).add(PrayerRequest(
            id: '',
            userId: ref.read(currentUserIdProvider) ?? '',
            userName: ref.read(displayNameProvider),
            request: text,
            status: 'pending',
          ));
      if (mounted) _say('Prayer request posted.');
    } catch (_) {
      if (mounted) _say('Could not post your prayer request. Please try again.');
    }
  }

  Future<void> _editPrayerRequest(PrayerRequest request) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _PrayerDialog(
        title: 'Edit Prayer Request',
        submitLabel: 'Save',
        initialText: request.request,
      ),
    );
    if (text == null || text == request.request || !mounted) return;

    try {
      await ref.read(prayerRepositoryProvider).updateText(request.id, text);
      if (mounted) _say('Prayer request updated.');
    } catch (_) {
      if (mounted) _say('Could not save your changes. Please try again.');
    }
  }

  Future<void> _deletePrayerRequest(PrayerRequest request) async {
    if (!await confirmDelete(context, itemLabel: 'prayer request')) return;
    try {
      await ref.read(prayerRepositoryProvider).delete(request.id);
      if (mounted) _say('Prayer request deleted.');
    } catch (_) {
      if (mounted) _say('Could not delete the prayer request. Please try again.');
    }
  }

  Future<void> _toggleStatus(PrayerRequest request) async {
    try {
      await ref
          .read(prayerRepositoryProvider)
          .updateStatus(request.id, request.isAnswered ? 'pending' : 'answered');
    } catch (_) {
      if (mounted) _say('Could not update the prayer request. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canModerate = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canSeeAllPrayerRequests,
          orElse: () => false,
        );
    final currentUserId = ref.watch(currentUserIdProvider);
    final requestsAsync = ref.watch(prayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: canModerate
                  ? 'No prayer requests yet.'
                  : 'You have not submitted any prayer requests.\nTap + to share one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final isOwner = currentUserId != null && request.userId == currentUserId;
              return _PrayerCard(
                request: request,
                showRequester: canModerate,
                isOwner: isOwner,
                canModerate: canModerate,
                onEdit: () => _editPrayerRequest(request),
                onToggleStatus: () => _toggleStatus(request),
                onDelete: () => _deletePrayerRequest(request),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New prayer request',
        onPressed: _addPrayerRequest,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Roomy writing box for a prayer point. Owns its own controller so it is
/// disposed only after the dialog has finished closing.
class _PrayerDialog extends StatefulWidget {
  const _PrayerDialog({
    required this.title,
    required this.submitLabel,
    this.initialText = '',
  });

  final String title;
  final String submitLabel;
  final String initialText;

  @override
  State<_PrayerDialog> createState() => _PrayerDialogState();
}

class _PrayerDialogState extends State<_PrayerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: SizedBox(
        // Takes the full width the dialog allows (up to 560 on a computer).
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 7,
            maxLines: 14,
            maxLength: prayerRequestMaxLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What would you like prayer for?',
              hintText: 'Write your prayer point here...',
              alignLabelWithHint: true,
            ),
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Please write something' : null,
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.request,
    required this.showRequester,
    required this.isOwner,
    required this.canModerate,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final PrayerRequest request;
  final bool showRequester;
  final bool isOwner;
  final bool canModerate;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // The person who posted it can always manage it; leaders can mark or delete
    // anyone's, but only the owner can reword it.
    final hasMenu = isOwner || canModerate;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: request.isAnswered ? AppColors.blue : AppColors.primary,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              request.isAnswered ? Icons.check_circle_outline : Icons.volunteer_activism,
              color: request.isAnswered ? AppColors.blue : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.request, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TagChip(
                        label: request.isAnswered ? 'Answered' : 'Pending',
                        color: request.isAnswered ? AppColors.blue : AppColors.secondaryDark,
                        icon: request.isAnswered ? Icons.check : Icons.hourglass_empty,
                      ),
                      if (showRequester)
                        Text('From: ${request.userName}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (request.createdAt != null)
                        Text(formatDate(request.createdAt!),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            if (hasMenu)
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'toggle') onToggleStatus();
                },
                itemBuilder: (context) => [
                  if (isOwner)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(request.isAnswered ? 'Mark as pending' : 'Mark as answered'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
