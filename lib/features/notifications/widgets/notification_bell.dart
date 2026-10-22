import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/notifications_provider.dart';
import '../screens/notifications_screen.dart';

/// Bell with the number of new announcements and events since you last looked.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return IconButton(
      tooltip: unread == 0 ? 'Notifications' : 'Notifications ($unread new)',
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_outlined, size: 28),
      ),
    );
  }
}
