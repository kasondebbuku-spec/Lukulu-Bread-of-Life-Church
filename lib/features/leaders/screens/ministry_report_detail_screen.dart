import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/ministry_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../../models/ministry_report.dart';
import 'ministry_report_form_screen.dart';

/// One ministry report: the leader can correct or withdraw it until it has been
/// reviewed; the Pastor (or Admin) reads it, replies and marks it reviewed.
class MinistryReportDetailScreen extends ConsumerStatefulWidget {
  const MinistryReportDetailScreen({super.key, required this.report});

  final MinistryReport report;

  @override
  ConsumerState<MinistryReportDetailScreen> createState() =>
      _MinistryReportDetailScreenState();
}

class _MinistryReportDetailScreenState
    extends ConsumerState<MinistryReportDetailScreen> {
  late final _note = TextEditingController(text: widget.report.pastorNote);
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// The latest copy, so a review shows up here without leaving the screen.
  MinistryReport _latest() {
    for (final list in [
      ref.watch(allMinistryReportsProvider).asData?.value,
      ref.watch(myMinistryReportsProvider).asData?.value,
    ]) {
      for (final r in list ?? const <MinistryReport>[]) {
        if (r.id == widget.report.id) return r;
      }
    }
    return widget.report;
  }

  Future<void> _review(MinistryReport r) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ministryReportRepositoryProvider).markReviewed(r.id,
          note: _note.text.trim(), reviewer: ref.read(displayNameProvider));
      messenger.showSnackBar(
          const SnackBar(content: Text('Marked as reviewed.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not save. Nothing was changed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MinistryReport r) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw this report?'),
        content: const Text('The Pastor will no longer see it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Withdraw')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(ministryReportRepositoryProvider).delete(r.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Report withdrawn.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not withdraw the report. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _latest();
    final access = ref.watch(userRoleProvider).asData?.value ?? UserAccess.member;
    final uid = ref.watch(currentUserIdProvider);
    final isAuthor = uid != null && uid == r.authorUid;
    final canEdit = isAuthor && !r.isReviewed;
    final reviewer = access.canReviewMinistryReports;
    final theme = Theme.of(context);

    Widget section(String title, String body) => body.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(body),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Change',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MinistryReportFormScreen(existing: r))),
            ),
            IconButton(
              tooltip: 'Withdraw',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(r),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
                child: Text(r.ministry, style: theme.textTheme.headlineSmall)),
            TagChip(
              label: r.isReviewed ? 'Reviewed' : (reviewer ? 'New' : 'Sent'),
              color: r.isReviewed ? AppColors.primary : AppColors.blue,
            ),
          ]),
          const SizedBox(height: 4),
          Text('${r.authorName}, ${r.position}'),
          Text('For ${formatDate(r.period)}'),
          if (r.attendance > 0) Text('${r.attendance} attended'),
          section('What happened', r.summary),
          section('Challenges', r.challenges),
          section('What is needed', r.needs),
          if (r.isReviewed) ...[
            const Divider(height: 32),
            Text(
                'Reviewed by ${r.reviewedBy.isEmpty ? 'the Pastor' : r.reviewedBy}'
                '${r.reviewedAt == null ? '' : ' on ${formatDate(r.reviewedAt!)}'}',
                key: const Key('reviewed-line'),
                style: theme.textTheme.titleSmall),
            if (r.pastorNote.isNotEmpty && !reviewer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(r.pastorNote, key: const Key('pastor-note')),
              ),
          ],
          if (reviewer) ...[
            const Divider(height: 32),
            Text(r.isReviewed ? 'Your reply' : 'Reply and mark reviewed',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              key: const Key('review-note'),
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: reportNotesMaxLength,
              decoration: const InputDecoration(
                  hintText: 'A word back to the leader (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('mark-reviewed'),
              onPressed: _busy ? null : () => _review(r),
              icon: const Icon(Icons.done_all),
              label: Text(r.isReviewed ? 'Update reply' : 'Mark as reviewed'),
            ),
          ],
        ],
      ),
    );
  }
}
