import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ministry_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tag_chip.dart';
import 'ministry_report_detail_screen.dart';
import 'ministry_report_form_screen.dart';

enum _Filter { all, fresh, reviewed }

/// Ministry reports. A leader sees the reports they have sent and can write a
/// new one; the Pastor (and Admin) see everyone's and mark them reviewed.
class MinistryReportsScreen extends ConsumerStatefulWidget {
  const MinistryReportsScreen({super.key});

  @override
  ConsumerState<MinistryReportsScreen> createState() =>
      _MinistryReportsScreenState();
}

class _MinistryReportsScreenState extends ConsumerState<MinistryReportsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(userRoleProvider).asData?.value ?? UserAccess.member;
    if (!access.hasPosition && !access.canReviewMinistryReports) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ministry Reports')),
        body: const EmptyState(
            icon: Icons.assignment_outlined,
            message: 'Ministry reports are for ministry leaders and the Pastor.\n'
                'Ask for your position from Leaders.'),
      );
    }

    final reviewer = access.canReviewMinistryReports;
    final reports = ref.watch(reviewer
        ? allMinistryReportsProvider
        : myMinistryReportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(reviewer ? 'Ministry Reports' : 'My Reports')),
      floatingActionButton: access.hasPosition
          ? FloatingActionButton.extended(
              key: const Key('new-report'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MinistryReportFormScreen())),
              icon: const Icon(Icons.edit_note),
              label: const Text('New report'),
            )
          : null,
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('The reports could not be loaded.')),
        data: (all) {
          final shown = all.where((r) {
            if (!reviewer) return true;
            return switch (_filter) {
              _Filter.all => true,
              _Filter.fresh => !r.isReviewed,
              _Filter.reviewed => r.isReviewed,
            };
          }).toList();
          final fresh = all.where((r) => !r.isReviewed).length;

          if (all.isEmpty) {
            return EmptyState(
                icon: Icons.assignment_outlined,
                message: reviewer
                    ? 'No reports have been sent yet.'
                    : 'You have not sent a report yet.\nTap New report to write one.');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (reviewer) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      fresh == 0
                          ? 'Everything has been reviewed.'
                          : '$fresh waiting to be reviewed',
                      key: const Key('reports-summary'),
                      style: theme.textTheme.titleMedium),
                ),
                Wrap(spacing: 8, children: [
                  for (final (f, label) in [
                    (_Filter.all, 'All'),
                    (_Filter.fresh, 'New'),
                    (_Filter.reviewed, 'Reviewed'),
                  ])
                    ChoiceChip(
                      key: Key('filter-${f.name}'),
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ]),
              ],
              if (shown.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Nothing here.'))),
              for (final r in shown)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    key: Key('report-${r.id}'),
                    title: Text('${r.ministry} · ${formatDate(r.period)}'),
                    subtitle: Text(
                        '${reviewer ? '${r.authorName}, ${r.position}\n' : ''}'
                        '${r.summary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: TagChip(
                      label: r.isReviewed
                          ? 'Reviewed'
                          : (reviewer ? 'New' : 'Sent'),
                      color: r.isReviewed ? AppColors.primary : AppColors.blue,
                    ),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MinistryReportDetailScreen(report: r))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
