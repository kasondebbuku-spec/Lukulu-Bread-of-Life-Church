import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'dashboard_panel.dart';

class QuickAccessItem {
  const QuickAccessItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// 2x2 grid of shortcut tiles to the screens the signed-in role uses most.
class QuickAccessCard extends StatelessWidget {
  const QuickAccessCard({super.key, required this.items});

  final List<QuickAccessItem> items;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Quick Access',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [for (final item in items) _Tile(item: item)],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 26),
            const SizedBox(height: 6),
            Text(item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
