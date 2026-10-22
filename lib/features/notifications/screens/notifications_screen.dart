import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/app_notification.dart';
import '../../announcements/screens/announcements_screen.dart';
import '../../events/screens/events_screen.dart';

/// New announcements and events. Opening it marks everything as seen, but the
/// items that were new when you arrived stay highlighted until you leave.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// What "new" meant when this screen opened. Captured once the profile has
  /// loaded (not before, or everything would look new), and only then is the
  /// count cleared, so the items you came to read stay highlighted.
  DateTime? _seenAtOnOpen;
  bool _captured = false;

  void _captureAndMarkSeen() {
    _captured = true;
    _seenAtOnOpen = ref.read(notificationsSeenAtProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(notificationServiceProvider).markAllSeen();
      } catch (_) {
        // Not being able to clear the count is not worth interrupting reading.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_captured && ref.watch(userProfileProvider).hasValue) {
      _captureAndMarkSeen();
    }
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              message: 'You are all caught up.\nNew announcements and events will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final seen = _seenAtOnOpen;
                final isNew = _captured && (seen == null || item.at.isAfter(seen));
                final isEvent = item.kind == NotificationKind.event;
                return ListTile(
                  tileColor: isNew ? const Color(0xFFFFF8E1) : null,
                  leading: Icon(isEvent ? Icons.event : Icons.campaign,
                      color: AppColors.primary),
                  title: Text(item.title,
                      style: TextStyle(
                          fontWeight: isNew ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text('${item.detail}\n${formatDate(item.at)}'),
                  isThreeLine: true,
                  trailing: isNew
                      ? const Icon(Icons.circle, size: 10, color: AppColors.secondaryDark)
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => isEvent
                            ? const EventsScreen()
                            : const AnnouncementsScreen()),
                  ),
                );
              },
            ),
    );
  }
}
