import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/service_report.dart';

/// The built-in PDF font only has the Latin characters, and phone keyboards add
/// curly quotes, long dashes and the like. This swaps those for plain ones so a
/// printout never loses words or fails.
String pdfSafe(String text) {
  final plain = text
      .replaceAll(RegExp('[‘’‚′]'), "'")
      .replaceAll(RegExp('[“”„″]'), '"')
      .replaceAll(RegExp('[‐-―−]'), '-')
      .replaceAll('…', '...')
      .replaceAll('•', '-')
      .replaceAll('\t', ' ')
      .replaceAll('\r', '');
  return String.fromCharCodes(
      plain.runes.map((r) => r == 10 || (r >= 32 && r <= 255) ? r : 63));
}

String serviceReportPdfFilename(ServiceReport? report) {
  if (report == null) return 'service-report-blank.pdf';
  String two(int n) => n.toString().padLeft(2, '0');
  final d = report.date;
  return 'service-report-${d.year}-${two(d.month)}-${two(d.day)}-${report.serviceType.name}.pdf';
}

const _dots = '.......................................................................';
const _text = pw.TextStyle(fontSize: 10.5);
final _bold = pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold);

/// The Sunday Service Summary Report as a two-page PDF matching the paper form.
/// With [report] left null it prints a blank form to fill in by hand.
Future<Uint8List> buildServiceReportPdf(ServiceReport? report) async {
  final doc = pw.Document();
  final r = report;
  String v(String? s) => pdfSafe((s ?? '').trim());

  pw.Widget field(String label, String? value, {double indent = 0}) {
    final shown = v(value);
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent, bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label: ', style: _bold),
          pw.Expanded(
              child: pw.Text(shown.isEmpty ? _dots : shown,
                  style: _text, maxLines: shown.isEmpty ? 1 : null)),
        ],
      ),
    );
  }

  /// A long piece of writing. Kept as its own page item so it can run on to the
  /// next page.
  List<pw.Widget> writing(String label, String? value, {int blankLines = 3}) {
    final shown = v(value);
    return [
      pw.Padding(
          padding: const pw.EdgeInsets.only(left: 18, bottom: 3),
          child: pw.Text('$label:', style: _bold)),
      if (shown.isEmpty)
        for (var i = 0; i < blankLines; i++)
          pw.Padding(
              padding: const pw.EdgeInsets.only(left: 18, bottom: 6),
              child: pw.Text(_dots + _dots.substring(0, 20), style: _text, maxLines: 1))
      else
        pw.Text(shown, style: _text, overflow: pw.TextOverflow.span),
      pw.SizedBox(height: 5),
    ];
  }

  List<pw.Widget> numbered(String title, List<String> items, int blankRows) {
    final rows = items.where((x) => x.trim().isNotEmpty).toList();
    final count = rows.length > blankRows ? rows.length : blankRows;
    return [
      pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
          child: pw.Text(title, style: _bold)),
      for (var i = 0; i < count; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 5),
          child: pw.Text('${i + 1}.  ${i < rows.length ? pdfSafe(rows[i].trim()) : _dots}',
              style: _text, maxLines: i < rows.length ? null : 1),
        ),
    ];
  }

  String count(int n) => r == null ? '............' : '$n';
  String money(Object? x) =>
      x is double ? formatZmw(x) : (r == null ? '............' : formatZmw(0));

  final testimonies =
      r?.testimonies.where((t) => !t.isEmpty).toList() ?? const <Testimony>[];
  final testimonyRows = testimonies.length > 2 ? testimonies.length : 2;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        pw.Center(
          child: pw.Text("(BOL CHURCH INT'L - LUKULU) SUNDAY SERVICE SUMMARY REPORT",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(
              flex: 3, child: field('TYPE OF SERVICE (Routine/Special)', r?.serviceType.label)),
          pw.Expanded(flex: 2, child: field('DATE', r == null ? null : formatDate(r.date))),
        ]),
        pw.SizedBox(height: 4),
        pw.Text('PROGRAMME', style: _bold),
        pw.SizedBox(height: 5),
        field('Opening Prayer (Given By)', r?.openingPrayerBy),
        field('Morning Intercession (Led By)', r?.intercessionBy),
        field('Praises (Led By)', r?.praisesBy),
        field('Worship (Led By)', r?.worshipBy),
        field('Leaders on duty',
            r?.leadersOnDuty.where((x) => x.trim().isNotEmpty).join(', ')),
        field('Announcements (Given By)', r?.announcementsBy),
        field('Exhortation (Given By)', r?.exhortationBy),
        field('Title', r?.exhortationTitle, indent: 18),
        field('Scripture Reading', r?.exhortationReading, indent: 18),
        field('Main Word (Preacher)', r?.preacher),
        field('Title', r?.wordTitle, indent: 18),
        field('Scripture Reading', r?.wordReading, indent: 18),
        ...writing('Message (In Summary)', r?.wordSummary, blankLines: 6),
        pw.Text('Testimonies:', style: _bold),
        pw.SizedBox(height: 4),
        for (var i = 0; i < testimonyRows; i++) ...[
          field('${i + 1}. Given By (Name)',
              i < testimonies.length ? testimonies[i].name : null),
          ...writing('Narration of Testimony in Summary',
              i < testimonies.length ? testimonies[i].summary : null,
              blankLines: 2),
        ],
        field('Closing Prayer (Given By)', r?.closingPrayerBy),
        pw.SizedBox(height: 6),
        pw.Text(
            'Attendance:  Men ${count(r?.men ?? 0)}    Women ${count(r?.women ?? 0)}    '
            'Children ${count(r?.children ?? 0)}    Total: ${count(r?.attendanceTotal ?? 0)}',
            style: _text),
        pw.SizedBox(height: 8),
        pw.Text(
            'Collections: (Total ${r == null ? 'K ............' : formatZmw(r.collectionsTotal)})',
            style: _bold),
        pw.SizedBox(height: 4),
        pw.Wrap(spacing: 16, runSpacing: 4, children: [
          for (final c in serviceCollectionOrder)
            pw.Text('${serviceCollectionLabel(c)}: ${money(r?.collections[c])}',
                style: _text),
        ]),

        // ---- page 2 ----
        pw.NewPage(),
        pw.Center(
            child: pw.Text('ANNOUNCEMENTS',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        field('Announcements (Given By)', r?.noticesBy),
        ...numbered(
            'Visitors (Names and Origin):',
            [
              for (final x in r?.visitors ?? const <Visitor>[])
                if (!x.isEmpty)
                  x.origin.trim().isEmpty ? x.name : '${x.name} - ${x.origin}',
            ],
            5),
        ...numbered(
            'Notifications (Special Announcements: Absent with apology, patients, newly born babies etc)',
            r?.notices ?? const [],
            7),
        ...numbered(
            'Special Offering (Tithers, Honored pledges, offering in absentia, calling for pledges etc)',
            r?.specialOffering ?? const [],
            5),
        ...numbered('Leaders on duty for the upcoming week:',
            r?.nextWeekLeaders ?? const [], 2),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final (role, name, signature) in [
              ('Secretary', r?.secretaryName, r?.secretarySignature),
              ('Treasurer', r?.treasurerName, r?.treasurerSignature),
              ('Elder', r?.elderName, r?.elderSignature),
            ])
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(role, style: _bold),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Name: ${v(name).isEmpty ? '..........................' : v(name)}',
                          style: _text),
                      pw.SizedBox(height: 4),
                      pw.Text('Signature:', style: _text),
                      pw.Container(
                        height: 36,
                        child: signature != null
                            ? pw.Image(pw.MemoryImage(signature), fit: pw.BoxFit.contain)
                            : pw.Align(
                                alignment: pw.Alignment.bottomLeft,
                                child: pw.Text('..............................', style: _text)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Center(child: pw.Text('End/...', style: _text)),
      ],
    ),
  );
  return doc.save();
}
