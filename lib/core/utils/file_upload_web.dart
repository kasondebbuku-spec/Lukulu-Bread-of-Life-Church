import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens the browser's file chooser for an Excel (.xlsx) file and returns the
/// file's bytes, or null if the person cancels. The file is read here in the
/// browser; it is not sent anywhere.
Future<Uint8List?> pickSpreadsheetBytes() {
  final completer = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  void finish(Uint8List? bytes) {
    if (!completer.isCompleted) completer.complete(bytes);
    input.remove();
  }

  input.addEventListener(
      'change',
      ((web.Event _) {
        final file = input.files?.item(0);
        if (file == null) {
          finish(null);
          return;
        }
        file.arrayBuffer().toDart.then(
          (buffer) => finish(buffer.toDart.asUint8List()),
          onError: (Object e) {
            if (!completer.isCompleted) completer.completeError(e);
            input.remove();
          },
        );
      }).toJS);
  // Newer browsers tell us when the chooser is closed without a file.
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

  web.document.body?.append(input);
  input.click();
  return completer.future;
}
