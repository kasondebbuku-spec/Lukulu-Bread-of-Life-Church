import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/week_utils.dart';
import '../../../repositories/repository_providers.dart';
import '../zmw_denominations.dart';
import 'giving_screen.dart' show formatZmw;

class WeeklyStatementScreen extends ConsumerStatefulWidget {
  const WeeklyStatementScreen({super.key});

  @override
  ConsumerState<WeeklyStatementScreen> createState() => _WeeklyStatementScreenState();
}

class _WeeklyStatementScreenState extends ConsumerState<WeeklyStatementScreen> {
  DateTime _selectedSunday = sundayOnOrBefore(DateTime.now());

  Future<void> _pickSunday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSunday,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      selectableDayPredicate: (d) => d.weekday == DateTime.sunday,
    );
    if (picked != null) setState(() => _selectedSunday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(givingRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Statement')),
      body: recordsAsync.when(
        data: (_) {
          final summary = ref.watch(weekSummaryProvider(_selectedSunday));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text('Week of ${formatDate(_selectedSunday)}'),
                  subtitle: const Text('Tap to change'),
                  onTap: _pickSunday,
                ),
              ),
              const SizedBox(height: 16),
              _StatRow(label: 'Tithe', value: summary.titheTotal, color: AppColors.secondaryDark),
              _StatRow(label: 'Offering', value: summary.offeringTotal, color: AppColors.blue),
              _StatRow(
                  label: 'Special Offering',
                  value: summary.specialOfferingTotal,
                  color: AppColors.primary),
              if (summary.otherTotal > 0)
                _StatRow(
                    label: 'Uncategorized',
                    value: summary.otherTotal,
                    color: AppColors.textSecondary),
              const Divider(height: 32),
              _StatRow(
                label: 'Grand Total',
                value: summary.grandTotal,
                color: AppColors.primaryDark,
                emphasized: true,
              ),
              const SizedBox(height: 24),
              Text('Offering Denomination Breakdown',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (!summary.hasDenominationData)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No denomination breakdown recorded for this week.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: zmwDenominations
                        .where((d) => (summary.denominationCounts[d.key] ?? 0) > 0)
                        .map((d) {
                      final count = summary.denominationCounts[d.key]!;
                      return ListTile(
                        dense: true,
                        title: Text('${d.label} × $count'),
                        trailing: Text(formatZmw(d.value * count)),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: emphasized
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              formatZmw(value),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: emphasized ? 20 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
