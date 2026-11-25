import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/pledge.dart';

/// One pledge: how much, by when, how much has been given and how much is left.
class PledgeCard extends StatelessWidget {
  const PledgeCard({
    super.key,
    required this.progress,
    this.showMember = false,
    this.onChange,
    this.onCancel,
  });

  final PledgeProgress progress;

  /// Show whose pledge it is (for the Finance Officer's list).
  final bool showMember;
  final VoidCallback? onChange;
  final VoidCallback? onCancel;

  static (String, Color) _look(PledgeState s) => switch (s) {
        PledgeState.fulfilled => ('Fulfilled', AppColors.primary),
        PledgeState.overdue => ('Overdue', AppColors.goldInk),
        PledgeState.dueSoon => ('Due soon', AppColors.secondaryDark),
        PledgeState.upcoming => ('On track', AppColors.textSecondary),
        PledgeState.cancelled => ('Cancelled', AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress.pledge;
    final (label, colour) = _look(progress.state);
    final editable = onChange != null && onCancel != null && !p.isCancelled;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formatZmw(p.amount),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TagChip(label: label, color: colour),
                if (editable)
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    onSelected: (v) {
                      if (v == 'change') onChange!();
                      if (v == 'cancel') onCancel!();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'change', child: Text('Change')),
                      PopupMenuItem(value: 'cancel', child: Text('Cancel pledge')),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            if (showMember)
              Text(p.memberName, style: theme.textTheme.bodyMedium),
            Text('To be given by ${formatDate(p.dueDate)}',
                style: theme.textTheme.bodySmall),
            if (p.note.isNotEmpty) Text(p.note, style: theme.textTheme.bodySmall),
            if (!p.isCancelled) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 8,
                    color: colour == AppColors.textSecondary ? AppColors.primary : colour,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress.state == PledgeState.fulfilled
                    ? '${formatZmw(progress.paid)} given. Thank you!'
                    : '${formatZmw(progress.paid)} given  •  ${formatZmw(progress.remaining)} to go',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
