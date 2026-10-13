import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/file_download_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../../../repositories/repository_providers.dart';
import '../export/giving_export.dart';
import '../zmw_denominations.dart';

/// Download giving records and Sunday Income Forms as spreadsheets (CSV) for
/// backup or for working with in Excel / Google Sheets.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  /// null means all years.
  int? _year;

  void _download(String filename, String content) {
    try {
      ref.read(fileDownloaderProvider)(filename, content);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Downloading $filename')));
    } on UnsupportedError {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Downloads are only available in the web app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final giving = ref.watch(givingRecordsProvider);
    final forms = ref.watch(incomeFormsProvider);

    if (giving.isLoading || forms.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export data')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (giving.hasError || forms.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export data')),
        body: const Center(child: Text('The data could not be loaded.')),
      );
    }

    final allGiving = giving.value ?? const <GivingRecord>[];
    final allForms = forms.value ?? const <SundayIncomeForm>[];
    final years = ({
      ...allGiving.map((r) => r.date.year),
      ...allForms.map((f) => f.date.year),
    }.toList()
      ..sort((a, b) => b.compareTo(a)));
    final year = years.contains(_year) ? _year : null;

    final shownGiving =
        allGiving.where((r) => year == null || r.date.year == year).toList();
    final shownForms =
        allForms.where((f) => year == null || f.date.year == year).toList();
    final suffix = year?.toString() ?? 'all';
    final valuesByKey = {for (final d in zmwDenominations) d.key: d.value};

    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Download your records as spreadsheets (CSV). They open in Excel or '
              'Google Sheets, and make a handy backup to keep somewhere safe.'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Period:  '),
              DropdownButton<int?>(
                value: year,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All years')),
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) => setState(() => _year = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ExportCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Giving records',
            subtitle:
                '${shownGiving.length} record(s): date, category, description, amount, currency',
            enabled: shownGiving.isNotEmpty,
            onDownload: () => _download('giving-$suffix.csv', givingCsv(shownGiving)),
          ),
          _ExportCard(
            icon: Icons.receipt_long_outlined,
            title: 'Sunday Income Forms',
            subtitle:
                '${shownForms.length} form(s): totals by category, Natsave, expenses, attendance, sign-off names',
            enabled: shownForms.isNotEmpty,
            onDownload: () => _download(
                'income-forms-$suffix.csv', incomeFormsCsv(shownForms, valuesByKey)),
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onDownload,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: enabled ? onDownload : null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
