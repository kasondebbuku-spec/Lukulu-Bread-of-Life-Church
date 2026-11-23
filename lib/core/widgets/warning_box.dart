import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A gold notice box with a warning icon, used for "this does not add up"
/// messages that never block saving.
class WarningBox extends StatelessWidget {
  const WarningBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldInk.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.goldInk),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.goldInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.goldInk)),
          ),
        ],
      ),
    );
  }
}
