import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_format.dart';
import '../../../models/forex_entry.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';
import '../../../core/utils/currency_format.dart';
import '../zmw_denominations.dart';

/// Builds a clean, paginated PDF replica of the church's "Income Analysis
/// Breakdown (Form 2)" for one saved [SundayIncomeForm], for printing or
/// filing. Reuses the same formatting helpers the app screens use, so the
/// PDF can never show different numbers than what's on screen.
Future<Uint8List> buildIncomeFormPdf(
  SundayIncomeForm form,
  Map<String, double> valuesByKey,
) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('Bread of Life Church International - Lukulu',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Income Analysis Breakdown (Form 2)',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text(
              '${formatDate(form.date)} — ${form.service.label} service',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ],
      ),
      build: (context) => [
        for (final c in GivingCategory.values)
          _categorySection(c, form.categoryBlocks[c]!, valuesByKey),
        _overallSection(form, valuesByKey),
        if (form.forexEntries.isNotEmpty) _forexSection(form),
        if (form.chequeEntries.isNotEmpty) _chequeSection(form),
        _attendanceSection(form),
        _summarySection(form, valuesByKey),
        _signaturesSection(form),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _sectionHeading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _categorySection(
  GivingCategory category,
  CategoryBlock block,
  Map<String, double> valuesByKey,
) {
  final rows = zmwDenominations
      .where((d) => (block.denominationBreakdown[d.key] ?? 0) > 0)
      .map((d) {
    final count = block.denominationBreakdown[d.key]!;
    return [d.label, '$count', formatZmw(d.value * count)];
  }).toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading(category.label),
      if (rows.isEmpty)
        pw.Text('No entries.', style: const pw.TextStyle(fontSize: 10))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Note/Coin', 'Count', 'Amount (K)'],
          data: rows,
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sub-total: ${formatZmw(block.amount(valuesByKey))}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}

pw.Widget _overallSection(SundayIncomeForm form, Map<String, double> valuesByKey) {
  final counts = form.overallDenominationCounts();
  final rows = zmwDenominations.where((d) => (counts[d.key] ?? 0) > 0).map((d) {
    final count = counts[d.key]!;
    return [d.label, '$count', formatZmw(d.value * count)];
  }).toList();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Overall (combined denominations)'),
      if (rows.isEmpty)
        pw.Text('No entries.', style: const pw.TextStyle(fontSize: 10))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Note/Coin', 'Count', 'Amount (K)'],
          data: rows,
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Overall cash total: ${formatZmw(form.overallCashTotal(valuesByKey))}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ],
  );
}

pw.Widget _forexSection(SundayIncomeForm form) {
  final rows = form.forexEntries
      .map((f) => [f.currency.label, f.amount.toStringAsFixed(2), formatZmw(f.kwachaValue)])
      .toList();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Forex'),
      pw.TableHelper.fromTextArray(
        headers: ['Currency', 'Amount', 'Kwacha Value'],
        data: rows,
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Total Kwacha Value: ${formatZmw(form.totalForexKwacha)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );
}

pw.Widget _chequeSection(SundayIncomeForm form) {
  final rows = form.chequeEntries
      .map((c) => [c.name, c.chequeNo, formatZmw(c.amount)])
      .toList();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Cheques'),
      pw.TableHelper.fromTextArray(
        headers: ['Name', 'Cheque No.', 'Amount'],
        data: rows,
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Sub-total (Cheques): ${formatZmw(form.totalCheques)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );
}

pw.Widget _attendanceSection(SundayIncomeForm form) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Attendance'),
      pw.TableHelper.fromTextArray(
        headers: ['Men', 'Women', 'Children', 'Total'],
        data: [
          ['${form.men}', '${form.women}', '${form.children}', '${form.attendanceTotal}']
        ],
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _summarySection(SundayIncomeForm form, Map<String, double> valuesByKey) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Summary'),
      pw.TableHelper.fromTextArray(
        headers: ['', 'Amount (K)'],
        data: [
          for (final c in GivingCategory.values)
            [c.label, formatZmw(form.categoryAmount(c, valuesByKey))],
          if (form.forexEntries.isNotEmpty)
            ['Forex (Kwacha value)', formatZmw(form.totalForexKwacha)],
          if (form.chequeEntries.isNotEmpty) ['Cheques', formatZmw(form.totalCheques)],
          ['Grand Total', formatZmw(form.grandTotal(valuesByKey))],
          ['20% of Tithe (remittance)', formatZmw(form.twentyPercentOfTithe(valuesByKey))],
        ],
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _signaturesSection(SundayIncomeForm form) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Sign-off'),
      pw.Text('Prepared By: ${form.preparedBy}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Checked By: ${form.checkedBy}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Collected By: ${form.collectedBy}', style: const pw.TextStyle(fontSize: 10)),
    ],
  );
}
