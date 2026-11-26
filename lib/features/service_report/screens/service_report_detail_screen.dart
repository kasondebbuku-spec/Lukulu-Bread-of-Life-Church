import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_report_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/service_report.dart';
import '../../giving/pdf/pdf_actions.dart';
import '../pdf/service_report_pdf.dart';
import 'service_report_form_screen.dart';

/// A saved Sunday Service Report, laid out like the paper form, with printing.
/// The Secretariat and Admin can correct it; only the Admin can delete it.
class ServiceReportDetailScreen extends ConsumerWidget {
  const ServiceReportDetailScreen({super.key, required this.report});

  final ServiceReport report;

  Future<void> _delete(BuildContext context, WidgetRef ref, ServiceReport r) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text('The report for ${formatDate(r.date)} will be removed for '
            'everyone. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(serviceReportRepositoryProvider).delete(r.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Report deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not delete the report. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userRoleProvider).asData?.value;
    // the latest copy, so a correction shows here straight away
    final saved = ref.watch(serviceReportsProvider).asData?.value ?? const [];
    final r = saved.firstWhere((x) => x.id == report.id, orElse: () => report);
    final theme = Theme.of(context);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(text,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        );

    Widget line(String label, String value) => value.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: value),
            ])),
          );

    Widget numbered(String title, List<String> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              for (var i = 0; i < items.length; i++) Text('${i + 1}. ${items[i]}'),
            ],
          );

    final name = serviceReportPdfFilename(r);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Report'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => printPdf(context,
                filename: name, build: () => buildServiceReportPdf(r)),
          ),
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => downloadPdf(context,
                filename: name, build: () => buildServiceReportPdf(r)),
          ),
          if (access?.canWriteServiceReports == true)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ServiceReportFormScreen(existing: r))),
            ),
          if (access?.isAdmin == true)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, r),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BOL Church Int'l - Lukulu · Sunday Service Summary Report",
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('${r.serviceType.label} service · ${formatDate(r.date)}',
                        key: const Key('sr-detail-title')),
                    if (r.enteredBy.isNotEmpty)
                      Text('Entered by ${r.enteredBy}',
                          style: theme.textTheme.bodySmall),
                    heading('Programme'),
                    line('Opening Prayer', r.openingPrayerBy),
                    line('Morning Intercession', r.intercessionBy),
                    line('Praises', r.praisesBy),
                    line('Worship', r.worshipBy),
                    line('Leaders on duty', r.leadersOnDuty.join(', ')),
                    line('Announcements', r.announcementsBy),
                    line('Exhortation', r.exhortationBy),
                    line('Exhortation title', r.exhortationTitle),
                    line('Exhortation reading', r.exhortationReading),
                    line('Main Word (preacher)', r.preacher),
                    line('Title', r.wordTitle),
                    line('Scripture reading', r.wordReading),
                    line('Message in summary', r.wordSummary),
                    for (var i = 0; i < r.testimonies.length; i++) ...[
                      line('Testimony ${i + 1} by', r.testimonies[i].name),
                      line('Testimony ${i + 1}', r.testimonies[i].summary),
                    ],
                    line('Closing Prayer', r.closingPrayerBy),
                    heading('Attendance'),
                    Text('Men ${r.men}   Women ${r.women}   Children ${r.children}'
                        '   Total ${r.attendanceTotal}'),
                    heading('Collections'),
                    for (final c in serviceCollectionOrder)
                      if ((r.collections[c] ?? 0) > 0)
                        line(serviceCollectionLabel(c), formatZmw(r.collections[c]!)),
                    Text('Total ${formatZmw(r.collectionsTotal)}',
                        key: const Key('sr-detail-total'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Divider(height: 36),
                    heading('Announcements'),
                    line('Given by', r.noticesBy),
                    numbered('Visitors', [
                      for (final v in r.visitors)
                        v.origin.isEmpty ? v.name : '${v.name} - ${v.origin}',
                    ]),
                    numbered('Notifications', r.notices),
                    numbered('Special offering', r.specialOffering),
                    numbered('Leaders on duty next week', r.nextWeekLeaders),
                    heading('Signatures'),
                    for (final (role, who, signature) in [
                      ('Secretary', r.secretaryName, r.secretarySignature),
                      ('Treasurer', r.treasurerName, r.treasurerSignature),
                      ('Elder', r.elderName, r.elderSignature),
                    ]) ...[
                      Text('$role: ${who.isEmpty ? 'not filled in' : who}'),
                      if (signature != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 6),
                          child: Container(
                            color: Colors.white,
                            child: Image.memory(signature, height: 60),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
