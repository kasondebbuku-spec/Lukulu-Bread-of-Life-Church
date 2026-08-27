import 'package:flutter/material.dart';

import 'confirm_delete_dialog.dart';

/// A delete button that confirms before calling [onConfirmed] — the
/// confirm-then-delete pattern repeated across every editable list screen.
class DeleteIconButton extends StatelessWidget {
  const DeleteIconButton({
    super.key,
    required this.itemLabel,
    required this.onConfirmed,
  });

  final String itemLabel;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () async {
        if (await confirmDelete(context, itemLabel: itemLabel)) {
          onConfirmed();
        }
      },
    );
  }
}
