import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_format.dart';
import '../../../models/giving_record.dart';
import '../../../models/member_giving_statement.dart';

// Text here must stay plain ASCII: the built-in PDF font has no Unicode glyphs.

String _money(String currency, double amount) => '$currency ${amount.toStringAsFixed(2)}';

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows,
        {Map<int, pw.Alignment>? alignments}) =>
    pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellAlignments: alignments,
    );

/// A member's personal statement of giving for one year, for their own records.
Future<Uint8List> buildMemberStatementPdf(
  MemberGivingStatement statement, {
  required DateTime generatedOn,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('Bread of Life Church International - Lukulu',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Statement of Giving ${statement.year}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text('${statement.memberName}  |  Prepared ${formatDate(generatedOn)}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        if (statement.isEmpty)
          pw.Text('No contributions are recorded against your account for ${statement.year}.',
              style: const pw.TextStyle(fontSize: 10)),
        for (final c in statement.currencies) ...[
          _heading('${c.currency} - total ${_money(c.currency, c.total)}'),
          _table(
            ['Category', 'Amount'],
            [
              for (final cat in GivingCategory.values)
                if ((c.byCategory[cat] ?? 0) > 0)
                  [cat.label, _money(c.currency, c.byCategory[cat]!)],
              if (c.uncategorized > 0)
                ['Other', _money(c.currency, c.uncategorized)],
            ],
            alignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 8),
          _table(
            ['Month', 'Amount'],
            [
              for (var m = 0; m < 12; m++)
                if (c.byMonth[m] > 0) [monthName(m + 1), _money(c.currency, c.byMonth[m])],
            ],
            alignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 8),
          pw.Text('Contributions', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          _table(
            ['Date', 'Category', 'Reference', 'Amount'],
            [
              for (final r in c.records)
                [
                  formatDate(r.date),
                  r.category?.label ?? 'Contribution',
                  r.id,
                  _money(c.currency, r.amount),
                ],
            ],
            alignments: {3: pw.Alignment.centerRight},
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          'This statement lists the contributions the Finance team has recorded '
          'against your account. Gifts that were not linked to your account, such '
          'as cash in the general offering, are not included. If anything looks '
          'missing or incorrect, please contact the Finance team and quote the '
          'reference.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );

  return doc.save();
}
