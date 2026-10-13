/// Builds CSV text that opens cleanly in Excel and Google Sheets.
///
/// - Cells containing commas, quotes or line breaks are quoted (quotes doubled).
/// - Text starting with `=`, `+`, `-`, `@`, tab or carriage return gets a leading
///   apostrophe so a spreadsheet never runs it as a formula (a name typed as
///   `=HYPERLINK(...)` must stay plain text). Numbers are written as numbers.
/// - A UTF-8 byte-order mark is added so Excel reads non-English names correctly.
String toCsv(List<List<Object?>> rows) {
  final buffer = StringBuffer('﻿');
  for (final row in rows) {
    buffer.write(row.map(_cell).join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _cell(Object? value) {
  if (value == null) return '';
  if (value is num) return _number(value);
  if (value is bool) return value ? 'Yes' : 'No';

  var text = value.toString();
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) text = "'$text";
  final needsQuotes = text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r');
  return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
}

String _number(num n) {
  if (n is int) return '$n';
  final d = n.toDouble();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
}
