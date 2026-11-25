import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/ministry_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/ministry_position.dart';
import '../../../models/ministry_report.dart';

/// Writing (or correcting) a report to the Pastor.
class MinistryReportFormScreen extends ConsumerStatefulWidget {
  const MinistryReportFormScreen({super.key, this.existing});

  /// Set when correcting a report that has not been reviewed yet.
  final MinistryReport? existing;

  @override
  ConsumerState<MinistryReportFormScreen> createState() =>
      _MinistryReportFormScreenState();
}

class _MinistryReportFormScreenState
    extends ConsumerState<MinistryReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  MinistryPosition? _position;
  late DateTime _period = widget.existing?.period ?? DateTime.now();
  late final _attendance = TextEditingController(
      text: (widget.existing?.attendance ?? 0) > 0
          ? '${widget.existing!.attendance}'
          : '');
  late final _summary = TextEditingController(text: widget.existing?.summary ?? '');
  late final _challenges =
      TextEditingController(text: widget.existing?.challenges ?? '');
  late final _needs = TextEditingController(text: widget.existing?.needs ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_attendance, _summary, _challenges, _needs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.isAfter(today) ? today : _period,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null) setState(() => _period = picked);
  }

  Future<void> _save(Map<String, MinistryPosition> positions) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(ministryReportRepositoryProvider);
    final day = DateTime(_period.year, _period.month, _period.day);
    final attendance = int.tryParse(_attendance.text.trim()) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing != null) {
        await repo.change(existing.id,
            period: day,
            attendance: attendance,
            summary: _summary.text.trim(),
            challenges: _challenges.text.trim(),
            needs: _needs.text.trim());
        messenger.showSnackBar(const SnackBar(content: Text('Report updated.')));
      } else {
        final uid = ref.read(currentUserIdProvider);
        final p = _position ?? (positions.length == 1 ? positions.values.first : null);
        if (uid == null || p == null) throw StateError('no position');
        await repo.add(MinistryReport(
          id: '',
          authorUid: uid,
          authorName: ref.read(displayNameProvider),
          ministryKey: p.key,
          ministry: p.ministry,
          position: p.title,
          period: day,
          attendance: attendance,
          summary: _summary.text.trim(),
          challenges: _challenges.text.trim(),
          needs: _needs.text.trim(),
        ));
        messenger.showSnackBar(
            const SnackBar(content: Text('Report sent to the Pastor.')));
      }
      navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the report. Nothing was saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions =
        ref.watch(userRoleProvider).asData?.value.positions ?? const {};
    final existing = widget.existing;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
          title: Text(existing == null ? 'New report' : 'Change report')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (existing != null)
              Text('${existing.ministry} · ${existing.position}',
                  style: theme.textTheme.titleMedium)
            else if (positions.isEmpty)
              const Text('You do not hold a ministry position yet.')
            else
              DropdownButtonFormField<MinistryPosition>(
                key: const Key('report-ministry'),
                initialValue: positions.length == 1 ? positions.values.first : _position,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Ministry', prefixIcon: Icon(Icons.groups_outlined)),
                items: [
                  for (final p in positions.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (p) => setState(() => _position = p),
                validator: (p) => p == null ? 'Choose the ministry' : null,
              ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Report for (date)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_period)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('report-attendance'),
              controller: _attendance,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'How many attended (optional)',
                  prefixIcon: Icon(Icons.people_outline)),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n != null && n > reportMaxAttendance) return 'That number is too large';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('report-summary'),
              controller: _summary,
              minLines: 5,
              maxLines: 10,
              maxLength: reportSummaryMaxLength,
              decoration: const InputDecoration(
                  labelText: 'What happened',
                  hintText: 'Activities, rehearsals, visits, how it went...',
                  alignLabelWithHint: true),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Tell the Pastor what happened' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('report-challenges'),
              controller: _challenges,
              minLines: 2,
              maxLines: 5,
              maxLength: reportNotesMaxLength,
              decoration: const InputDecoration(
                  labelText: 'Challenges (optional)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('report-needs'),
              controller: _needs,
              minLines: 2,
              maxLines: 5,
              maxLength: reportNotesMaxLength,
              decoration: const InputDecoration(
                  labelText: 'What you need (optional)',
                  hintText: 'Prayer, items, support, money...',
                  alignLabelWithHint: true),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    key: const Key('report-error'),
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('send-report'),
              onPressed: _saving || (existing == null && positions.isEmpty)
                  ? null
                  : () => _save(positions),
              icon: const Icon(Icons.send),
              label: Text(_saving
                  ? 'Sending...'
                  : existing == null
                      ? 'Send to the Pastor'
                      : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
