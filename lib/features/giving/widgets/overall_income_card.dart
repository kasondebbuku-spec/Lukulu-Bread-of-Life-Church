import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../zmw_denominations.dart';

/// Everything counted at the Sunday service, combined by note and coin
/// whichever category it came from: all the K500s, all the K200s, all the
/// K100s and so on, with the overall cash total underneath.
class OverallIncomeCard extends StatelessWidget {
  const OverallIncomeCard({super.key, required this.counts});

  /// How many of each note or coin were counted in all, keyed like
  /// [zmwDenominations] (`'500'`, `'0.5'`, ...).
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      for (final d in zmwDenominations)
        if ((counts[d.key] ?? 0) > 0) (d, counts[d.key]!),
    ];
    final total = rows.fold(0.0, (sum, r) => sum + r.$1.value * r.$2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sunday Service Overall Income (all categories combined)',
                style: theme.textTheme.titleMedium),
            const Divider(),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('No cash counted yet.', style: theme.textTheme.bodyMedium),
              )
            else
              for (final (d, count) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(d.label)),
                      Expanded(
                          flex: 2,
                          child: Text('x $count', textAlign: TextAlign.center)),
                      Expanded(
                          flex: 4,
                          child: Text(formatZmw(d.value * count),
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text('Overall cash total',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Text(formatZmw(total),
                    style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
