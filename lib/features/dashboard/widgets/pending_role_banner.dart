import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/role_request.dart';

/// Tells someone who asked for roles that the Admin has not yet approved them.
/// Each leaves the list once decided; the notice disappears with the last one.
class PendingRoleBanner extends ConsumerWidget {
  const PendingRoleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(ownPendingRoleRequestsProvider);
    if (waiting.isEmpty) return const SizedBox.shrink();
    final roles = inWords([for (final r in waiting) r.label]);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondaryDark),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_top, color: AppColors.secondaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waiting for Admin approval',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('You asked to be $roles. Until the Admin approves, you can '
                      'carry on using the app with what you already have. This '
                      'notice disappears by itself once it is decided.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
