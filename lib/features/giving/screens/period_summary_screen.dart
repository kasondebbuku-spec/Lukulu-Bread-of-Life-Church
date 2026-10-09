import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../models/period_summary.dart';
import '../../../models/sunday_income_form.dart';
import '../../../repositories/repository_providers.dart';
import '../giving_theme.dart';
import '../pdf/pdf_actions.dart';
import '../pdf/period_summary_pdf.dart';
import '../zmw_denominations.dart';

/// Monthly and yearly roll-up of giving, bank deposits, expenses and
/// attendance, printable for filing.
class PeriodSummaryScreen extends ConsumerStatefulWidget {
  const PeriodSummaryScreen({super.key});

  @override
  ConsumerState<PeriodSummaryScreen> createState() => _PeriodSummaryScreenState();
}

class _PeriodSummaryScreenState extends ConsumerState<PeriodSummaryScreen> {
  bool _yearly = false;
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _thisMonth => DateTime(DateTime.now().year, DateTime.now().month);

  DateTime _shift(DateTime from, int steps) => _yearly
      ? DateTime(from.year + steps)
      : DateTime(from.year, from.month + steps);

  bool get _canGoForward {
    final next = _shift(_start, 1);
    return _yearly
        ? next.year <= DateTime.now().year
        : !next.isAfter(_thisMonth);
  }

  void _setYearly(bool yearly) => setState(() {
        _yearly = yearly;
        _start = yearly ? DateTime(_start.year) : DateTime(_start.year, _start.month);
      });

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(givingRecordsProvider);
    final forms = ref.watch(incomeFormsProvider).maybeWhen(
          data: (f) => f,
          orElse: () => const <SundayIncomeForm>[],
        );

    return records.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Summary')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Summary')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (data) {
        final summary = PeriodSummary.compute(
          start: _start,
          isYear: _yearly,
          records: data,
          forms: forms,
          valuesByKey: {for (final d in zmwDenominations) d.key: d.value},
        );
        return _buildScaffold(context, summary);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, PeriodSummary summary) {
    final f = summary.formTotals;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download PDF',
            onPressed: () => downloadPdf(context,
                filename: summary.pdfFilename,
                build: () => buildPeriodSummaryPdf(summary)),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => printPdf(context,
                filename: summary.pdfFilename,
                build: () => buildPeriodSummaryPdf(summary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Month')),
              ButtonSegment(value: true, label: Text('Year')),
            ],
            selected: {_yearly},
            onSelectionChanged: (s) => _setYearly(s.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous',
                  onPressed: () => setState(() => _start = _shift(_start, -1)),
                ),
                Expanded(
                  child: Text(summary.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next',
                  onPressed: _canGoForward
                      ? () => setState(() => _start = _shift(_start, 1))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final c in GivingCategory.values)
            _Line(c.label, summary.categoryTotals[c] ?? 0, categoryColor(c)),
          if (summary.otherTotal > 0)
            _Line('Uncategorized', summary.otherTotal, AppColors.textSecondary),
          const Divider(height: 28),
          _Line('Grand Total', summary.grandTotal, AppColors.primaryDark,
              emphasized: true),
          if (f.hasForms) ...[
            const SizedBox(height: 20),
            Text('Bank deposit & expenses',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _Line('Tithe of Tithes (20%)', f.titheOfTithes, AppColors.secondary),
            _Line('Natsave Deposit', f.natsaveDeposit, AppColors.primaryDark),
            _Line('Total Collection', f.totalCollection, AppColors.secondaryDark,
                emphasized: true),
            _Line('Expenses + Tithe of Tithes Reserve', f.expensesReserve,
                AppColors.goldInk),
            _Line('Total Expenses', f.totalExpenses, AppColors.goldInk),
            if (f.unreconciledCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.goldInk.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.goldInk),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, color: AppColors.goldInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${f.unreconciledCount} of ${f.formCount} form(s) in this '
                        'period do not reconcile.',
                        style: const TextStyle(color: AppColors.goldInk),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _Plain('Services recorded', '${summary.serviceCount}'),
                    _Plain('Total attendance', '${summary.totalAttendance}'),
                    _Plain('Average per service',
                        summary.averageAttendance.toStringAsFixed(1)),
                  ],
                ),
              ),
            ),
          ],
          if (summary.weeks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Giving by week', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final w in summary.weeks)
                    ListTile(
                      dense: true,
                      title: Text('Week of ${formatDate(w.sunday)}'),
                      trailing: Text(formatZmw(w.total),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No giving recorded for this period.'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, this.color, {this.emphasized = false});

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
            Flexible(
              child: Text(
                label,
                style: emphasized
                    ? Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            Text(formatZmw(value),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: emphasized ? 20 : 16)),
          ],
        ),
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
