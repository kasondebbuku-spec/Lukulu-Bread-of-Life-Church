import '../core/utils/date_format.dart';
import 'announcement.dart';
import 'church_event.dart';

enum NotificationKind { announcement, event }

/// One "something new was posted" entry. Derived from announcements and events,
/// never stored, so it can never disagree with them.
class AppNotification {
  const AppNotification({
    required this.kind,
    required this.title,
    required this.detail,
    required this.at,
  });

  final NotificationKind kind;
  final String title;
  final String detail;

  /// When it was posted.
  final DateTime at;
}

/// Anything older than this is no longer news.
const notificationWindow = Duration(days: 30);

/// New announcements and events from the last [notificationWindow], newest first.
/// Items without a posted time (still being saved) are left out until they have one.
List<AppNotification> buildNotifications({
  required List<Announcement> announcements,
  required List<ChurchEvent> events,
  required DateTime now,
}) {
  final cutoff = now.subtract(notificationWindow);
  final items = <AppNotification>[
    for (final a in announcements)
      if (a.createdAt != null && a.createdAt!.isAfter(cutoff))
        AppNotification(
          kind: NotificationKind.announcement,
          title: a.title,
          detail: a.createdBy.isEmpty ? 'New announcement' : 'Announcement from ${a.createdBy}',
          at: a.createdAt!,
        ),
    for (final e in events)
      if (e.createdAt != null && e.createdAt!.isAfter(cutoff))
        AppNotification(
          kind: NotificationKind.event,
          title: e.title,
          detail: [
            'New event on ${formatDate(e.date)}',
            if (e.location.isNotEmpty) e.location,
          ].join(' - '),
          at: e.createdAt!,
        ),
  ];
  items.sort((a, b) => b.at.compareTo(a.at));
  return items;
}

/// How many were posted after the person last opened their notifications.
/// Never opened them (null) means everything in the window is new.
int unreadCount(List<AppNotification> items, DateTime? seenAt) =>
    seenAt == null ? items.length : items.where((n) => n.at.isAfter(seenAt)).length;
