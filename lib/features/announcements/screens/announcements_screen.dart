import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_list_view.dart';
import '../../../core/widgets/delete_icon_button.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/announcement.dart';
import '../../../repositories/repository_providers.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedAudience = 'all';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _addAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    final announcement = Announcement(
      id: '',
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdBy: user?.displayName ?? user?.email ?? 'unknown',
      targetAudience: _selectedAudience,
    );
    await ref.read(announcementsRepositoryProvider).add(announcement);

    if (!mounted) return;
    _titleController.clear();
    _contentController.clear();
    _selectedAudience = 'all';
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New Announcement'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: 3,
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAudience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('Everyone (all members)')),
                      DropdownMenuItem(
                          value: 'leaders',
                          child:
                              Text('Leaders only (admin, secretariat, pastor)')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedAudience = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: _addAnnouncement, child: const Text('Post')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canPostAnnouncements,
          orElse: () => false,
        );
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: AsyncListView<Announcement>(
        asyncValue: announcementsAsync,
        padding: const EdgeInsets.symmetric(vertical: 8),
        emptyIcon: Icons.campaign_outlined,
        emptyMessage: 'No announcements yet.\nBranch-wide updates will appear here.',
        itemBuilder: (context, announcement, index) {
          return _AnnouncementCard(
            announcement: announcement,
            canWrite: canWrite,
            onDelete: () => ref
                .read(announcementsRepositoryProvider)
                .delete(announcement.id),
          );
        },
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canWrite,
    required this.onDelete,
  });

  final Announcement announcement;
  final bool canWrite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLeadersOnly = announcement.targetAudience == 'leaders';
    final accent = isLeadersOnly ? AppColors.secondaryDark : AppColors.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canWrite)
                  DeleteIconButton(itemLabel: 'announcement', onConfirmed: onDelete),
              ],
            ),
            const SizedBox(height: 8),
            Text(announcement.content, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TagChip(
                  label: isLeadersOnly ? 'Leaders only' : 'Everyone',
                  color: accent,
                  icon: isLeadersOnly ? Icons.shield_outlined : Icons.public,
                ),
                Text(
                  'Posted by ${announcement.createdBy}'
                  '${announcement.createdAt != null ? ' • ${formatDate(announcement.createdAt!)}' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
