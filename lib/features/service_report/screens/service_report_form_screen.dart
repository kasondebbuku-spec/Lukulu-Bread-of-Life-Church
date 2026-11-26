import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/display_name_provider.dart';
import '../../../core/providers/service_report_providers.dart';
import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/warning_box.dart';
import '../../../models/giving_record.dart';
import '../../../models/service_report.dart';
import '../../giving/widgets/signature_pad_field.dart';

/// One row of a numbered list: one box, or two (a name and its details).
class _Row {
  _Row([String a = '', String b = ''])
      : first = TextEditingController(text: a),
        second = TextEditingController(text: b);

  final TextEditingController first;
  final TextEditingController second;

  bool get isEmpty => first.text.trim().isEmpty && second.text.trim().isEmpty;

  void dispose() {
    first.dispose();
    second.dispose();
  }
}

/// Filling in (or correcting) the Sunday Service Summary Report. It follows the
/// paper form from top to bottom. Nothing has to be complete to save it, so it
/// can be started during the service and finished later.
class ServiceReportFormScreen extends ConsumerStatefulWidget {
  const ServiceReportFormScreen({super.key, this.existing});

  final ServiceReport? existing;

  @override
  ConsumerState<ServiceReportFormScreen> createState() =>
      _ServiceReportFormScreenState();
}

class _ServiceReportFormScreenState extends ConsumerState<ServiceReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late ServiceType _type;
  final _text = <String, TextEditingController>{};
  final _money = <GivingCategory, TextEditingController>{};
  late final List<_Row> _onDuty;
  late final List<_Row> _testimonies;
  late final List<_Row> _visitors;
  late final List<_Row> _notices;
  late final List<_Row> _specialOffering;
  late final List<_Row> _nextWeek;
  final _secretarySignature = SignaturePadField.newController();
  final _treasurerSignature = SignaturePadField.newController();
  final _elderSignature = SignaturePadField.newController();

  bool _dirty = false;
  bool _prefilling = false;
  bool _saving = false;
  bool _drawing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final now = DateTime.now();
    _date = r?.date ?? DateTime(now.year, now.month, now.day);
    _type = r?.serviceType ?? ServiceType.routine;

    void add(String key, String value) =>
        _text[key] = TextEditingController(text: value)..addListener(_changed);
    add('openingPrayerBy', r?.openingPrayerBy ?? '');
    add('intercessionBy', r?.intercessionBy ?? '');
    add('praisesBy', r?.praisesBy ?? '');
    add('worshipBy', r?.worshipBy ?? '');
    add('announcementsBy', r?.announcementsBy ?? '');
    add('exhortationBy', r?.exhortationBy ?? '');
    add('exhortationTitle', r?.exhortationTitle ?? '');
    add('exhortationReading', r?.exhortationReading ?? '');
    add('preacher', r?.preacher ?? '');
    add('wordTitle', r?.wordTitle ?? '');
    add('wordReading', r?.wordReading ?? '');
    add('wordSummary', r?.wordSummary ?? '');
    add('closingPrayerBy', r?.closingPrayerBy ?? '');
    add('men', (r?.men ?? 0) > 0 ? '${r!.men}' : '');
    add('women', (r?.women ?? 0) > 0 ? '${r!.women}' : '');
    add('children', (r?.children ?? 0) > 0 ? '${r!.children}' : '');
    add('noticesBy', r?.noticesBy ?? '');
    add('secretaryName', r?.secretaryName ?? '');
    add('treasurerName', r?.treasurerName ?? '');
    add('elderName', r?.elderName ?? '');

    for (final c in serviceCollectionOrder) {
      final v = r?.collections[c] ?? 0;
      _money[c] = TextEditingController(
          text: v > 0 ? (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v') : '')
        ..addListener(_changed);
    }

    List<_Row> rows(List<_Row> filled, int blank) {
      final list = [...filled];
      while (list.length < blank) {
        list.add(_Row());
      }
      for (final x in list) {
        _watch(x);
      }
      return list;
    }

    _onDuty = rows([for (final x in r?.leadersOnDuty ?? const <String>[]) _Row(x)], 2);
    _testimonies = rows(
        [for (final t in r?.testimonies ?? const <Testimony>[]) _Row(t.name, t.summary)], 1);
    _visitors = rows(
        [for (final v in r?.visitors ?? const <Visitor>[]) _Row(v.name, v.origin)], 2);
    _notices = rows([for (final x in r?.notices ?? const <String>[]) _Row(x)], 3);
    _specialOffering =
        rows([for (final x in r?.specialOffering ?? const <String>[]) _Row(x)], 2);
    _nextWeek = rows([for (final x in r?.nextWeekLeaders ?? const <String>[]) _Row(x)], 2);

    for (final s in [_secretarySignature, _treasurerSignature, _elderSignature]) {
      s.addListener(_changed);
    }
    _dirty = false;

    // On a new report the Secretary's own name is filled in, as soon as we know
    // who they are. That is not "typing", so it does not count as unsaved work.
    if (r == null) {
      ref.listenManual(userRoleProvider, (_, next) {
        final box = _text['secretaryName']!;
        if (next.asData?.value.roles.contains(UserRole.secretariat) != true ||
            box.text.isNotEmpty) {
          return;
        }
        _prefilling = true;
        box.text = ref.read(displayNameProvider);
        _prefilling = false;
      }, fireImmediately: true);
    }
  }

  void _watch(_Row row) {
    row.first.addListener(_changed);
    row.second.addListener(_changed);
  }

  void _changed() {
    if (_prefilling) return;
    if (!_dirty) _dirty = true;
    // totals are shown as the numbers are typed
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    for (final c in _money.values) {
      c.dispose();
    }
    for (final list in [_onDuty, _testimonies, _visitors, _notices, _specialOffering, _nextWeek]) {
      for (final r in list) {
        r.dispose();
      }
    }
    _secretarySignature.dispose();
    _treasurerSignature.dispose();
    _elderSignature.dispose();
    super.dispose();
  }

  int _int(String key) => int.tryParse(_text[key]!.text.trim()) ?? 0;

  double _amount(GivingCategory c) => double.tryParse(_money[c]!.text.trim()) ?? 0;

  Map<GivingCategory, double> get _collections => {
        for (final c in serviceCollectionOrder)
          if (_amount(c) > 0) c: _amount(c),
      };

  static List<String> _lines(List<_Row> rows) => [
        for (final r in rows)
          if (r.first.text.trim().isNotEmpty) r.first.text.trim(),
      ];

  Future<Uint8List?> _signatureBytes(SignatureController c) async =>
      c.isEmpty ? null : c.toPngBytes();

  Future<ServiceReport> _build() async {
    String t(String k) => _text[k]!.text.trim();
    final old = widget.existing;
    return ServiceReport(
      id: old?.id ?? '',
      date: _date,
      serviceType: _type,
      openingPrayerBy: t('openingPrayerBy'),
      intercessionBy: t('intercessionBy'),
      praisesBy: t('praisesBy'),
      worshipBy: t('worshipBy'),
      leadersOnDuty: _lines(_onDuty),
      announcementsBy: t('announcementsBy'),
      exhortationBy: t('exhortationBy'),
      exhortationTitle: t('exhortationTitle'),
      exhortationReading: t('exhortationReading'),
      preacher: t('preacher'),
      wordTitle: t('wordTitle'),
      wordReading: t('wordReading'),
      wordSummary: t('wordSummary'),
      testimonies: [
        for (final r in _testimonies)
          if (!r.isEmpty)
            Testimony(name: r.first.text.trim(), summary: r.second.text.trim()),
      ],
      closingPrayerBy: t('closingPrayerBy'),
      men: _int('men'),
      women: _int('women'),
      children: _int('children'),
      collections: _collections,
      noticesBy: t('noticesBy'),
      visitors: [
        for (final r in _visitors)
          if (!r.isEmpty)
            Visitor(name: r.first.text.trim(), origin: r.second.text.trim()),
      ],
      notices: _lines(_notices),
      specialOffering: _lines(_specialOffering),
      nextWeekLeaders: _lines(_nextWeek),
      secretaryName: t('secretaryName'),
      treasurerName: t('treasurerName'),
      elderName: t('elderName'),
      secretarySignature:
          await _signatureBytes(_secretarySignature) ?? old?.secretarySignature,
      treasurerSignature:
          await _signatureBytes(_treasurerSignature) ?? old?.treasurerSignature,
      elderSignature: await _signatureBytes(_elderSignature) ?? old?.elderSignature,
      enteredBy: old?.enteredBy ?? ref.read(displayNameProvider),
      enteredByUid: old?.enteredByUid ?? ref.read(currentUserIdProvider) ?? '',
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _message =
          'Not saved yet. Please check the numbers marked in red above.');
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(serviceReportRepositoryProvider);

    // A second report for the same service is usually a mistake.
    if (widget.existing == null) {
      final saved = ref.read(serviceReportsProvider).asData?.value ?? const [];
      final clash =
          saved.any((r) => r.date == _date && r.serviceType == _type);
      if (clash) {
        final anyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('There is already a report'),
            content: Text(
                'A ${_type.label.toLowerCase()} service report for ${formatDate(_date)} '
                'is already saved. To correct it, cancel and open it from Service '
                'Reports. Save a second one anyway?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save anyway')),
            ],
          ),
        );
        if (anyway != true || !mounted) return;
      }
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final report = await _build();
      if (widget.existing == null) {
        await repo.add(report);
      } else {
        await repo.update(widget.existing!.id, report);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('Saved. You can find it again under Service Reports.')));
      navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not save the report. Nothing was saved, and what you typed is '
            'still here. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('What you have typed will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep filling in')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => navigator.pop());
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 5),
      lastDate: today.add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _dirty = true;
      });
    }
  }

  // ---- building blocks ----

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      );

  Widget _field(String key, String label,
          {int lines = 1, int max = serviceShortMaxLength}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextFormField(
          key: Key('sr-$key'),
          controller: _text[key],
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 6,
          maxLength: lines == 1 ? null : max,
          inputFormatters: lines == 1 ? [LengthLimitingTextInputFormatter(max)] : null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, alignLabelWithHint: lines > 1),
        ),
      );

  Widget _numberedList({
    required String id,
    required List<_Row> rows,
    required String label,
    String? secondLabel,
    int secondLines = 1,
    required String addLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ObjectKey(rows[i]),
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: Text('${i + 1}.'),
                ),
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        key: Key('sr-$id-$i'),
                        controller: rows[i].first,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                              secondLabel == null ? 300 : serviceShortMaxLength)
                        ],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(labelText: label),
                      ),
                      if (secondLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextFormField(
                            key: Key('sr-$id-b-$i'),
                            controller: rows[i].second,
                            minLines: secondLines,
                            maxLines: secondLines == 1 ? 1 : secondLines + 5,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                  secondLines == 1 ? serviceShortMaxLength : 2000)
                            ],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                                labelText: secondLabel,
                                alignLabelWithHint: secondLines > 1),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rows.length > 1)
                  IconButton(
                    tooltip: 'Remove line ${i + 1}',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() {
                      rows.removeAt(i).dispose();
                      _dirty = true;
                    }),
                  ),
              ],
            ),
          ),
        if (rows.length < serviceMaxRows)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('sr-add-$id'),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
              onPressed: () => setState(() {
                final row = _Row();
                _watch(row);
                rows.add(row);
              }),
            ),
          ),
      ],
    );
  }

  Widget _count(String key, String label) => Expanded(
        child: TextFormField(
          key: Key('sr-$key'),
          controller: _text[key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            return n != null && n > serviceMaxPeople ? 'Too large' : null;
          },
        ),
      );

  Widget _moneyField(GivingCategory c) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextFormField(
          key: Key('sr-money-${c.name}'),
          controller: _money[c],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: serviceCollectionLabel(c), prefixText: 'K '),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final n = double.tryParse(t);
            if (n == null || !n.isFinite || n < 0) return 'Enter an amount, e.g. 250';
            if (n > serviceMaxAmount) return 'That amount is too large';
            return null;
          },
        ),
      );

  Widget _signature(String role, SignatureController c, Uint8List? saved) =>
      SignaturePadField(
        label: saved == null
            ? '$role signature (optional)'
            : '$role signature -- saved one is kept unless you draw a new one',
        controller: c,
        onDrawingChanged: (down) => setState(() => _drawing = down),
      );

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(userRoleProvider).asData?.value;
    // keep the saved reports loaded, for the "already a report" check
    ref.watch(serviceReportsProvider);
    if (access?.canWriteServiceReports != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sunday Service Report')),
        body: const Center(
            child: Text('Only the Secretariat and Admin fill in this report.')),
      );
    }
    final old = widget.existing;
    final attendance = _int('men') + _int('women') + _int('children');
    final total = _collections.values.fold(0.0, (s, v) => s + v);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(old == null ? 'Sunday Service Report' : 'Change report')),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: _drawing ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("BOL Church Int'l - Lukulu · Sunday Service Summary Report",
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    SegmentedButton<ServiceType>(
                      segments: [
                        for (final t in ServiceType.values)
                          ButtonSegment(value: t, label: Text('${t.label} service')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() {
                        _type = s.first;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Date', suffixIcon: Icon(Icons.calendar_today)),
                        child: Text(formatDate(_date), key: const Key('sr-date')),
                      ),
                    ),
                    _heading('Programme'),
                    _field('openingPrayerBy', 'Opening Prayer (given by)'),
                    _field('intercessionBy', 'Morning Intercession (led by)'),
                    _field('praisesBy', 'Praises (led by)'),
                    _field('worshipBy', 'Worship (led by)'),
                    const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Leaders on duty')),
                    _numberedList(
                        id: 'duty',
                        rows: _onDuty,
                        label: 'Leader on duty',
                        addLabel: 'Add a leader'),
                    _field('announcementsBy', 'Announcements (given by)'),
                    _heading('Exhortation'),
                    _field('exhortationBy', 'Exhortation (given by)'),
                    _field('exhortationTitle', 'Exhortation title'),
                    _field('exhortationReading', 'Exhortation scripture reading'),
                    _heading('Main Word'),
                    _field('preacher', 'Main Word (preacher)'),
                    _field('wordTitle', 'Title of the message'),
                    _field('wordReading', 'Scripture reading'),
                    _field('wordSummary', 'Message (in summary)',
                        lines: 6, max: serviceSummaryMaxLength),
                    _heading('Testimonies'),
                    _numberedList(
                        id: 'testimony',
                        rows: _testimonies,
                        label: 'Given by (name)',
                        secondLabel: 'Testimony in summary',
                        secondLines: 2,
                        addLabel: 'Add a testimony'),
                    _field('closingPrayerBy', 'Closing Prayer (given by)'),
                    _heading('Attendance'),
                    Row(children: [
                      _count('men', 'Men'),
                      const SizedBox(width: 8),
                      _count('women', 'Women'),
                      const SizedBox(width: 8),
                      _count('children', 'Children'),
                    ]),
                    const SizedBox(height: 8),
                    Text('Total: $attendance',
                        key: const Key('sr-attendance-total'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    _heading('Collections'),
                    for (final c in serviceCollectionOrder) _moneyField(c),
                    const SizedBox(height: 8),
                    Text('Total: ${formatZmw(total)}',
                        key: const Key('sr-money-total'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                          'This report does not add to Giving or Attendance. Those come '
                          'from the Sunday Income Form.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    const Divider(height: 40),
                    _heading('Announcements'),
                    _field('noticesBy', 'Announcements page (given by)'),
                    const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Visitors')),
                    _numberedList(
                        id: 'visitor',
                        rows: _visitors,
                        label: "Visitor's name",
                        secondLabel: 'Where they come from',
                        addLabel: 'Add a visitor'),
                    const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Notifications: absent with apology, patients, '
                            'newly born babies and other special announcements')),
                    _numberedList(
                        id: 'notice',
                        rows: _notices,
                        label: 'Notification',
                        addLabel: 'Add a notification'),
                    const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Special offering: tithers, honoured pledges, '
                            'offering in absentia, calling for pledges')),
                    _numberedList(
                        id: 'special',
                        rows: _specialOffering,
                        label: 'Special offering',
                        addLabel: 'Add a line'),
                    const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Leaders on duty for the upcoming week')),
                    _numberedList(
                        id: 'nextweek',
                        rows: _nextWeek,
                        label: 'Leader',
                        addLabel: 'Add a leader'),
                    _heading('Signatures'),
                    _field('secretaryName', 'Secretary (name)'),
                    _signature('Secretary', _secretarySignature, old?.secretarySignature),
                    _field('treasurerName', 'Treasurer (name)'),
                    _signature('Treasurer', _treasurerSignature, old?.treasurerSignature),
                    _field('elderName', 'Elder (name)'),
                    _signature('Elder', _elderSignature, old?.elderSignature),
                    const SizedBox(height: 18),
                    if (_message != null) ...[
                      WarningBox(_message!, key: const Key('sr-message')),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      key: const Key('sr-save'),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save report'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
