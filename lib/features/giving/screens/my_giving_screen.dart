import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../repositories/repository_providers.dart';

class MyGivingScreen extends ConsumerStatefulWidget {
  const MyGivingScreen({super.key});
  @override
  ConsumerState<MyGivingScreen> createState() => _MyGivingScreenState();
}

class _MyGivingScreenState extends ConsumerState<MyGivingScreen> {
  DateTimeRange? range;
  bool tithesOnly = false;
  @override
  Widget build(BuildContext context) {
    final records = ref.watch(myGivingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Giving')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Your private giving history',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Only contributions linked to your account appear here. If an entry is missing or incorrect, contact the Finance team and quote its reference. Older entries may need to be linked by Finance.'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterChip(
              label: const Text('Tithes only'),
              selected: tithesOnly,
              onSelected: (value) => setState(() => tithesOnly = value)),
          OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(range == null
                  ? 'All dates'
                  : '${formatDate(range!.start)} – ${formatDate(range!.end)}'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialDateRange: range);
                if (picked != null && mounted) setState(() => range = picked);
              }),
          if (range != null)
            TextButton(
                onPressed: () => setState(() => range = null),
                child: const Text('Clear dates')),
        ]),
        const SizedBox(height: 16),
        records.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Column(children: [
            const Text('Your giving history could not be loaded.'),
            TextButton(
                onPressed: () => ref.invalidate(myGivingProvider),
                child: const Text('Retry')),
          ]),
          data: (all) {
            final end = range == null
                ? null
                : DateTime(
                    range!.end.year, range!.end.month, range!.end.day + 1);
            final filtered = all
                .where((r) =>
                    (!tithesOnly || r.category == GivingCategory.tithe) &&
                    (range == null ||
                        (!r.date.isBefore(range!.start) &&
                            r.date.isBefore(end!))))
                .toList();
            final totals = <String, double>{};
            for (final r in filtered) {
              totals.update(r.currency, (v) => v + r.amount,
                  ifAbsent: () => r.amount);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final total in totals.entries)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                                '${total.key} ${total.value.toStringAsFixed(2)} • Selected total',
                                style:
                                    Theme.of(context).textTheme.titleLarge))),
                  if (filtered.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child:
                            Text('No contributions found for this selection.')),
                  for (final record in filtered)
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.favorite_outline),
                      title: Text(
                          '${record.category?.label ?? 'Contribution'} • ${record.currency} ${record.amount.toStringAsFixed(2)}'),
                      subtitle: Text(
                          '${formatDate(record.date)}\nReference: ${record.id}'),
                      isThreeLine: true,
                    )),
                ]);
          },
        ),
      ]),
    );
  }
}
