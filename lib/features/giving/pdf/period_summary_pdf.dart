import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_format.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../models/period_summary.dart';
import '../../../models/trend.dart';

// Text here must stay plain ASCII: the built-in PDF font has no Unicode glyphs.

const _cell = pw.TextStyle(fontSize: 10);

pw.TextStyle get _head => pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows) =>
    pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      cellStyle: _cell,
      headerStyle: _head,
      cellAlignments: {
        for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
      },
    );

/// A clean, printable summary of one month or year for filing with the Pastor.
Future<Uint8List> buildPeriodSummaryPdf(PeriodSummary summary,
    {PeriodComparison? comparison}) async {
  final doc = pw.Document();
  final forms = summary.formTotals;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('Bread of Life Church International - Lukulu',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              summary.isYear ? 'Yearly Summary' : 'Monthly Summary',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text(summary.label, style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        _heading('Giving by category'),
        _table(['Category', 'Amount (K)'], [
          for (final c in GivingCategory.values)
            [c.label, formatZmw(summary.categoryTotals[c] ?? 0)],
          if (summary.otherTotal > 0)
            ['Uncategorized', formatZmw(summary.otherTotal)],
          ['Grand Total', formatZmw(summary.grandTotal)],
          if (forms.hasForms) ...[
            ['Less: Total Expenses', formatZmw(forms.totalExpenses)],
            ['Net Amount', formatZmw(summary.netAmount)],
          ],
        ]),
        if (comparison != null) ...[
          _heading('Compared with ${comparison.comparedWith}'),
          if (!comparison.hasEarlierFigures)
            pw.Text(
                'Nothing was recorded then, so there is nothing to compare with yet.',
                style: _cell)
          else ...[
            pw.Text(comparison.headline, style: _head),
            pw.SizedBox(height: 6),
            _table(['', 'Now', 'Before', 'Change', 'Remark'], [
              [
                'Giving',
                formatZmw(comparison.giving.current),
                formatZmw(comparison.giving.previous),
                comparison.giving.percentText,
                comparison.giving.word,
              ],
              [
                'Tithe',
                formatZmw(comparison.tithe.current),
                formatZmw(comparison.tithe.previous),
                comparison.tithe.percentText,
                comparison.tithe.word,
              ],
              [
                'Attendance per service',
                comparison.attendance.current.toStringAsFixed(1),
                comparison.attendance.previous.toStringAsFixed(1),
                comparison.attendance.percentText,
                comparison.attendance.word,
              ],
            ]),
          ],
          if (comparison.ongoing)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                  'This period is not over yet, so only the same stretch of the '
                  'earlier one is compared. The figures will change as more '
                  'Sundays are recorded.',
                  style: _cell),
            ),
        ],
        if (forms.hasForms) ...[
          _heading('Bank deposit and expenses'),
          _table(['', 'Amount (K)'], [
            ['Tithe of Tithes (10%)', formatZmw(forms.titheOfTithes)],
            ['Natsave Deposit', formatZmw(forms.natsaveDeposit)],
            ['Total Collection', formatZmw(forms.totalCollection)],
            ['Expenses Cash', formatZmw(forms.expensesReserve)],
          ]),
          if (forms.unreconciledCount > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                '${forms.unreconciledCount} of ${forms.formCount} form(s) in this '
                'period do not reconcile.',
                style: _head,
              ),
            ),
          _heading('Attendance'),
          _table(['', 'Value'], [
            ['Services recorded', '${summary.serviceCount}'],
            ['Total attendance', '${summary.totalAttendance}'],
            ['Average per service', summary.averageAttendance.toStringAsFixed(1)],
          ]),
        ],
        if (summary.weeks.isNotEmpty) ...[
          _heading('Giving by week'),
          _table(['Week of', 'Amount (K)'], [
            for (final w in summary.weeks) [formatDate(w.sunday), formatZmw(w.total)],
          ]),
        ],
      ],
    ),
  );

  return doc.save();
}
