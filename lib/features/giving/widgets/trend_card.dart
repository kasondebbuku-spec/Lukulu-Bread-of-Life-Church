import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../models/trend.dart';

/// "Compared with ..." card: giving, tithe and attendance against the
/// previous period, each as a percentage and a remark in words.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.comparison});

  final PeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compared with ${comparison.comparedWith}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!comparison.hasEarlierFigures)
              Text(
                  'Nothing was recorded then, so there is nothing to compare '
                  'with yet.',
                  style: theme.textTheme.bodyMedium)
            else ...[
              Text(comparison.headline,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _TrendRow(
                  label: 'Giving',
                  trend: comparison.giving,
                  format: formatZmw),
              _TrendRow(
                  label: 'Tithe', trend: comparison.tithe, format: formatZmw),
              _TrendRow(
                  label: 'Attendance per service',
                  trend: comparison.attendance,
                  format: (v) => v.toStringAsFixed(1)),
            ],
            if (comparison.ongoing) ...[
              const SizedBox(height: 8),
              Text(
                  'This period is not over yet, so only the same stretch of the '
                  'earlier one is compared. The figures will change as more '
                  'Sundays are recorded.',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow(
      {required this.label, required this.trend, required this.format});

  final String label;
  final Trend trend;
  final String Function(double) format;

  static Color _colour(TrendBand? band) => switch (band) {
        TrendBand.strongRise || TrendBand.rise => AppColors.primary,
        TrendBand.steady || null => AppColors.textSecondary,
        // Brand gold, never red: a dip is a prompt to look, not an alarm.
        TrendBand.dip || TrendBand.fall => AppColors.goldInk,
      };

  static IconData _icon(TrendBand? band) => switch (band) {
        TrendBand.strongRise || TrendBand.rise => Icons.trending_up,
        TrendBand.steady || null => Icons.trending_flat,
        TrendBand.dip || TrendBand.fall => Icons.trending_down,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = _colour(trend.band);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(trend.band), color: colour),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (trend.hasBaseline)
                  Text('${format(trend.current)} now, '
                      '${format(trend.previous)} before',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(trend.percentText,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: colour, fontWeight: FontWeight.w700)),
              Text(trend.word,
                  style: theme.textTheme.bodySmall?.copyWith(color: colour)),
            ],
          ),
        ],
      ),
    );
  }
}
