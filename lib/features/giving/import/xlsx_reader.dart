import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// One cell of a spreadsheet: its text or number, and whether it is a formula
/// (formula cells hold a calculated copy of the answer, which we may read but
/// should not mistake for something a person typed).
class SheetCell {
  const SheetCell(this.value, {this.isFormula = false});

  /// A [String] or a [double].
  final Object value;
  final bool isFormula;

  String? get text => value is String ? value as String : null;
  double? get number => value is num ? (value as num).toDouble() : null;
}

/// The cells of one worksheet, addressed by 1-based row and column.
class SheetData {
  SheetData(this.cells);

  final Map<(int, int), SheetCell> cells;

  SheetCell? cell(int row, int col) => cells[(row, col)];

  String? text(int row, int col) => cell(row, col)?.text;

  double? number(int row, int col) => cell(row, col)?.number;

  /// Every text cell, top to bottom then left to right.
  List<({int row, int col, String text})> get textCells {
    final out = [
      for (final e in cells.entries)
        if (e.value.text != null)
          (row: e.key.$1, col: e.key.$2, text: e.value.text!),
    ]..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
    return out;
  }
}

/// Reads the first worksheet of an Excel `.xlsx` file. An `.xlsx` is a zip of
/// XML files, so no spreadsheet program is needed; this is plain Dart and runs
/// in the browser.
///
/// Throws a [FormatException] when the bytes are not a readable `.xlsx`.
SheetData readFirstSheet(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Not an .xlsx file');
  }

  ArchiveFile? find(String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  // The first worksheet is normally sheet1.xml; otherwise take the lowest-numbered.
  final sheetFiles = archive.files
      .where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
      .toList()
    ..sort((a, b) => _sheetNumber(a.name).compareTo(_sheetNumber(b.name)));
  if (sheetFiles.isEmpty) throw const FormatException('No worksheet found');

  final sharedFile = find('xl/sharedStrings.xml');
  final shared = sharedFile == null ? const <String>[] : _sharedStrings(sharedFile);

  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(_utf8(sheetFiles.first));
  } catch (_) {
    throw const FormatException('Worksheet is not readable');
  }

  final cells = <(int, int), SheetCell>{};
  for (final c in doc.findAllElements('c')) {
    final ref = c.getAttribute('r');
    final pos = ref == null ? null : _position(ref);
    if (pos == null) continue;

    final type = c.getAttribute('t');
    final isFormula = c.getElement('f') != null;
    final raw = c.getElement('v')?.innerText;

    Object? value;
    switch (type) {
      case 's':
        final index = int.tryParse(raw ?? '');
        if (index != null && index >= 0 && index < shared.length) {
          value = shared[index];
        }
      case 'inlineStr':
        value = c.getElement('is')?.descendantElements
            .where((e) => e.name.local == 't')
            .map((e) => e.innerText)
            .join();
      case 'str':
        value = raw;
      case 'b' || 'e':
        value = null;
      default:
        value = raw == null ? null : double.tryParse(raw);
    }
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    cells[pos] = SheetCell(value, isFormula: isFormula);
  }
  return SheetData(cells);
}

int _sheetNumber(String name) =>
    int.parse(RegExp(r'sheet(\d+)\.xml$').firstMatch(name)!.group(1)!);

String _utf8(ArchiveFile f) =>
    utf8.decode(f.readBytes() ?? Uint8List(0), allowMalformed: true);

List<String> _sharedStrings(ArchiveFile file) {
  final doc = XmlDocument.parse(_utf8(file));
  return [
    for (final si in doc.findAllElements('si'))
      si.descendantElements
          // Skip phonetic hints; keep the real text runs.
          .where((e) => e.name.local == 't' &&
              !e.ancestorElements.any((a) => a.name.local == 'rPh'))
          .map((e) => e.innerText)
          .join(),
  ];
}

/// `B6` -> (6, 2).
(int, int)? _position(String ref) {
  final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(ref);
  if (m == null) return null;
  var col = 0;
  for (final ch in m.group(1)!.toUpperCase().codeUnits) {
    col = col * 26 + (ch - 64);
  }
  return (int.parse(m.group(2)!), col);
}
