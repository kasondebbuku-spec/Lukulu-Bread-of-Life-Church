import 'package:flutter/material.dart';

import '../../../core/constants/daily_verses.dart';
import '../../../core/theme/app_theme.dart';

class DailyVerseCard extends StatelessWidget {
  const DailyVerseCard({super.key, required this.verse});

  final DailyVerse verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF2C6),
            AppColors.secondaryLight.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Daily Verse',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.goldInk)),
              ),
              const Icon(Icons.wb_sunny_outlined, color: AppColors.goldInk),
            ],
          ),
          const SizedBox(height: 14),
          Text('"${verse.text}"',
              style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 12),
          Text(verse.reference,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.goldInk)),
        ],
      ),
    );
  }
}
