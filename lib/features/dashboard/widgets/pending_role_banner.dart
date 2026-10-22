import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Tells someone who asked for a role at sign-up that the Admin has not yet
/// approved it. Disappears by itself once approved or declined.
class PendingRoleBanner extends ConsumerWidget {
  const PendingRoleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(ownPendingRoleRequestProvider);
    if (role == null) return const SizedBox.shrink();
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
                  Text('You asked to be ${role.label}. Until the Admin approves it '
                      'you can use the app as a Member. This notice disappears '
                      'by itself once it is approved.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
