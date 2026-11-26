import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_report_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/service_report.dart';
import '../screens/service_report_form_screen.dart';
import '../screens/service_report_list_screen.dart';

/// On the Secretariat's (and Admin's) Home screen: the Sunday Service Report,
/// one tap away.
class ServiceReportHomeCard extends ConsumerWidget {
  const ServiceReportHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(userRoleProvider).asData?.value;
    if (access?.canWriteServiceReports != true) return const SizedBox.shrink();
    final latest = ref.watch(serviceReportsProvider).asData?.value.firstOrNull;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        key: const Key('home-service-report'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Sunday Service Report',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(latest == null
                  ? 'Programme, message, attendance, collections, visitors and announcements.'
                  : 'Last saved: ${formatDate(latest.date)} (${latest.serviceType.label})'
                      '${latest.enteredBy.isEmpty ? '' : ' by ${latest.enteredBy}'}'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const Key('home-fill-report'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Fill in report'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ServiceReportFormScreen())),
                ),
                OutlinedButton.icon(
                  key: const Key('home-past-reports'),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Past reports'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ServiceReportListScreen())),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
