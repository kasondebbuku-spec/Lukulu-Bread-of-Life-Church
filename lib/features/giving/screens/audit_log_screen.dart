import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/audit_entry.dart';
import '../../../repositories/repository_providers.dart';

/// Who created, edited or deleted Sunday Income Forms, newest first.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  static IconData _icon(AuditAction a) => switch (a) {
        AuditAction.create => Icons.add_circle_outline,
        AuditAction.update => Icons.edit_outlined,
        AuditAction.delete => Icons.delete_outline,
      };

  static Color _color(AuditAction a) => switch (a) {
        AuditAction.create => AppColors.blue,
        AuditAction.update => AppColors.goldInk,
        AuditAction.delete => AppColors.primaryDark,
      };

  static String _when(DateTime? t) {
    if (t == null) return 'just now';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${formatDate(t)} $h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(auditLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: log.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              message:
                  'No activity yet.\nSaves, edits and deletes of forms are listed here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _color(e.action).withValues(alpha: 0.12),
                    child: Icon(_icon(e.action), color: _color(e.action)),
                  ),
                  title: Text('${e.userName} ${e.action.label} a Sunday Income Form'),
                  subtitle: Text('${e.summary}\n${e.detail}\n${_when(e.createdAt)}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('The activity log could not be loaded.')),
      ),
    );
  }
}
