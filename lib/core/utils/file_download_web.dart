import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Saves [content] to the user's device as [filename] via a temporary download link.
void downloadTextFile(String filename, String content,
    {String mimeType = 'text/csv;charset=utf-8'}) {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(link);
  link.click();
  link.remove();
  // Give the browser a moment to start the download before releasing the blob.
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
