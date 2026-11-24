import 'dart:typed_data';

/// Lets the person choose an Excel file and returns its bytes (null if they
/// cancel). Only the web app can do this; other platforms throw so the caller
/// can say so instead of silently failing.
Future<Uint8List?> pickSpreadsheetBytes() {
  throw UnsupportedError('Choosing a file is only available in the web app.');
}
