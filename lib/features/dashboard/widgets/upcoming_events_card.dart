import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/church_event.dart';
import 'dashboard_panel.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

class UpcomingEventsCard extends StatelessWidget {
  const UpcomingEventsCard({
    super.key,
    required this.events,
    required this.onViewAll,
  });

  final AsyncValue<List<ChurchEvent>> events;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Upcoming Events',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: events.when(
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No upcoming events yet.'),
              )
            : Column(
                children: [for (final e in list.take(3)) _EventRow(event: e)],
              ),
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const Text('Events unavailable.'),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final ChurchEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2C6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(_months[event.date.month - 1],
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldInk)),
                Text('${event.date.day}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (event.location.isNotEmpty)
                  Text(event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
