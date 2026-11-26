import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_report_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/service_report.dart';
import '../../giving/pdf/pdf_actions.dart';
import '../pdf/service_report_pdf.dart';
import 'service_report_detail_screen.dart';
import 'service_report_form_screen.dart';

/// Every Sunday Service Report, newest first.
class ServiceReportListScreen extends ConsumerWidget {
  const ServiceReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userRoleProvider).asData?.value;
    if (access?.canViewServiceReports != true) {
      return const Scaffold(
          body: Center(child: Text('You do not have access to service reports.')));
    }
    final canWrite = access!.canWriteServiceReports;
    final reports = ref.watch(serviceReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Reports'),
        actions: [
          IconButton(
            key: const Key('print-blank'),
            tooltip: 'Print a blank form',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => printPdf(context,
                filename: serviceReportPdfFilename(null),
                build: () => buildServiceReportPdf(null)),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              key: const Key('new-service-report'),
              heroTag: 'new-service-report',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ServiceReportFormScreen())),
              icon: const Icon(Icons.edit_note),
              label: const Text('Fill in report'),
            )
          : null,
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('The reports could not be loaded.')),
        data: (all) => all.isEmpty
            ? EmptyState(
                icon: Icons.description_outlined,
                message: canWrite
                    ? 'No reports yet.\nTap Fill in report after the service.'
                    : 'No service reports have been saved yet.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final r = all[i];
                  final details = [
                    if (r.preacher.isNotEmpty) 'Preacher: ${r.preacher}',
                    if (r.attendanceTotal > 0) 'Attendance: ${r.attendanceTotal}',
                    if (r.enteredBy.isNotEmpty) 'Entered by ${r.enteredBy}',
                  ];
                  return Card(
                    child: ListTile(
                      key: Key('service-report-${r.id}'),
                      leading: const Icon(Icons.description_outlined,
                          color: AppColors.primary),
                      title: Text('${formatDate(r.date)} · ${r.serviceType.label}'),
                      subtitle: details.isEmpty ? null : Text(details.join('\n')),
                      isThreeLine: details.length > 1,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ServiceReportDetailScreen(report: r))),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
