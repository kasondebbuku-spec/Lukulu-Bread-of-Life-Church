import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Downloads a generated PDF as a file.
Future<void> downloadPdf(
  BuildContext context, {
  required String filename,
  required Future<Uint8List> Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Printing.sharePdf(bytes: await build(), filename: filename);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not create the PDF. Please try again.')));
  }
}

/// Opens the browser's print dialog; if that doesn't open (some browsers can't
/// print an embedded PDF), downloads the PDF so it can be printed from the file.
Future<void> printPdf(
  BuildContext context, {
  required String filename,
  required Future<Uint8List> Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Printing.layoutPdf(name: filename, onLayout: (_) => build())
        .timeout(const Duration(seconds: 20));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            "The print dialog didn't open, so the PDF was downloaded instead. Open it to print.")));
    if (context.mounted) {
      await downloadPdf(context, filename: filename, build: build);
    }
  }
}
