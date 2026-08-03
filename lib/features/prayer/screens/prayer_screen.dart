import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/prayer_request.dart';
import '../../../repositories/repository_providers.dart';

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestController = TextEditingController();

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _addPrayerRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    final request = PrayerRequest(
      id: '',
      userId: user?.uid ?? '',
      userName: user?.displayName ?? user?.email ?? 'Anonymous',
      request: _requestController.text.trim(),
      status: 'pending',
    );
    await ref.read(prayerRepositoryProvider).add(request);

    if (!mounted) return;
    _requestController.clear();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prayer Request'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _requestController,
            decoration: const InputDecoration(
                labelText: 'What would you like prayer for?'),
            maxLines: 3,
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _addPrayerRequest, child: const Text('Submit')),
        ],
      ),
    );
  }

  Future<void> _deletePrayerRequest(String docId) async {
    if (!await confirmDelete(context, itemLabel: 'prayer request')) return;
    await ref.read(prayerRepositoryProvider).delete(docId);
  }

  Future<void> _toggleStatus(PrayerRequest request) async {
    await ref
        .read(prayerRepositoryProvider)
        .updateStatus(request.id, request.isAnswered ? 'pending' : 'answered');
  }

  @override
  Widget build(BuildContext context) {
    final canSeeAll = ref.watch(userRoleProvider).maybeWhen(
          data: (role) => role.canSeeAllPrayerRequests,
          orElse: () => false,
        );
    final requestsAsync = ref.watch(prayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: canSeeAll
                  ? 'No prayer requests yet.'
                  : 'You have not submitted any prayer requests.\nTap + to share one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _PrayerCard(
                request: request,
                showRequester: canSeeAll,
                canManage: canSeeAll,
                onToggleStatus: () => _toggleStatus(request),
                onDelete: () => _deletePrayerRequest(request.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.request,
    required this.showRequester,
    required this.canManage,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final PrayerRequest request;
  final bool showRequester;
  final bool canManage;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
            if (canManage)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'toggle') onToggleStatus();
                },
                itemBuilder: (context) => [
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
