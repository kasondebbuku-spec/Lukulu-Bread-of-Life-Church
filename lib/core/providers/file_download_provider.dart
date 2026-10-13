import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/file_download.dart';

typedef FileDownloader = void Function(String filename, String content);

/// Indirection so screens can be tested without a browser.
final fileDownloaderProvider = Provider<FileDownloader>(
  (ref) => (filename, content) => downloadTextFile(filename, content),
);
