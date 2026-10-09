import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_theme.dart';

/// A labelled draw-your-signature box with a Clear button.
///
/// [onDrawingChanged] fires true while a finger/mouse is down on the pad so the
/// parent scroll view can stop scrolling and let the stroke be drawn.
class SignaturePadField extends StatelessWidget {
  const SignaturePadField({
    super.key,
    required this.label,
    required this.controller,
    this.onDrawingChanged,
  });

  final String label;
  final SignatureController controller;
  final ValueChanged<bool>? onDrawingChanged;

  /// Creates a controller styled for the app (dark purple ink on white).
  static SignatureController newController() => SignatureController(
        penStrokeWidth: 2.5,
        penColor: AppColors.primaryDark,
        exportBackgroundColor: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
              TextButton.icon(
                onPressed: controller.clear,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Listener(
            onPointerDown: (_) => onDrawingChanged?.call(true),
            onPointerUp: (_) => onDrawingChanged?.call(false),
            onPointerCancel: (_) => onDrawingChanged?.call(false),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Signature(
                controller: controller,
                height: 110,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
