import 'package:flutter/material.dart';

/// Shows a confirmation dialog and returns true if the user confirmed deletion.
Future<bool> confirmDelete(
  BuildContext context, {
  required String itemLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: Text('Are you sure you want to delete this $itemLabel?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
