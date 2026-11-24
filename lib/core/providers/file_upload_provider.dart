import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/file_upload.dart';

typedef SpreadsheetPicker = Future<Uint8List?> Function();

/// Indirection so screens can be tested without a browser.
final spreadsheetPickerProvider =
    Provider<SpreadsheetPicker>((ref) => pickSpreadsheetBytes);
