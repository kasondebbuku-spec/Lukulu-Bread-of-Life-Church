import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../models/member_giving_statement.dart';
import '../../../repositories/repository_providers.dart';
import '../pdf/member_statement_pdf.dart';
import '../pdf/pdf_actions.dart';

class MyGivingScreen extends ConsumerStatefulWidget {
  const MyGivingScreen({super.key});
  @override
  ConsumerState<MyGivingScreen> createState() => _MyGivingScreenState();
}

class _MyGivingScreenState extends ConsumerState<MyGivingScreen> {
  DateTimeRange? range;
  bool tithesOnly = false;
  int? statementYear;
  MemberGivingStatement _statement(List<GivingRecord> all, int year) =>
      MemberGivingStatement.compute(
        memberName: ref.read(displayNameProvider),
        year: year,
        records: all,
      );

  Widget _statementCard(List<GivingRecord> all) {
    final years = MemberGivingStatement.yearsWithGiving(all);
    if (years.isEmpty) return const SizedBox.shrink();
    final year = years.contains(statementYear) ? statementYear! : years.first;
    Future<Uint8List> build() =>
        buildMemberStatementPdf(_statement(all, year), generatedOn: DateTime.now());
    final filename = 'giving-statement-$year.pdf';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yearly statement',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('A printable summary of your recorded giving for a year.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  value: year,
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setState(() => statementYear = v),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                  onPressed: () =>
                      downloadPdf(context, filename: filename, build: build),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                  onPressed: () => printPdf(context, filename: filename, build: build),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                  _statementCard(all),
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
