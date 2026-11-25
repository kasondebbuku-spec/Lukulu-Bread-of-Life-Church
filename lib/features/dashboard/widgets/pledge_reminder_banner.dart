import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pledge_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../giving/screens/my_giving_screen.dart';

/// Reminds a member on their Home screen about a pledge that is due within a
/// week or already late, until it has been given. Disappears by itself.
class PledgeReminderBanner extends ConsumerWidget {
  const PledgeReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref
        .watch(myPledgeProgressProvider)
        .where((p) => p.needsReminder)
        .toList(); // already sorted: overdue first, then soonest due
    if (due.isEmpty) return const SizedBox.shrink();
    final first = due.first;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MyGivingScreen())),
        child: Container(
          key: const Key('pledge-reminder'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondaryDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.handshake_outlined, color: AppColors.secondaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pledge reminder',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(first.reminderText()),
                    if (due.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('and ${due.length - 1} more pledge'
                            '${due.length - 1 == 1 ? '' : 's'} to look at'),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
