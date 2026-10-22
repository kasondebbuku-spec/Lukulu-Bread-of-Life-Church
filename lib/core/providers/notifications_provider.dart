import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_notification.dart';
import '../../models/role_request.dart';
import '../../repositories/repository_providers.dart';
import '../../services/notification_service.dart';
import 'firebase_providers.dart';
import 'user_profile_provider.dart';
import 'user_role_provider.dart';

/// Recent announcements and new events, newest first.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final announcements = ref.watch(announcementsProvider).value ?? const [];
  final events = ref.watch(eventsProvider).value ?? const [];
  return buildNotifications(
      announcements: announcements, events: events, now: DateTime.now());
});

/// When this person last opened their notifications (null = never).
final notificationsSeenAtProvider = Provider<DateTime?>((ref) {
  final raw = ref.watch(userProfileProvider).value?['notificationsSeenAt'];
  return raw is Timestamp ? raw.toDate() : null;
});

final unreadNotificationsProvider = Provider<int>((ref) => unreadCount(
    ref.watch(notificationsProvider), ref.watch(notificationsSeenAtProvider)));

final notificationServiceProvider = Provider<NotificationService>((ref) =>
    NotificationService(ref.watch(firestoreProvider),
        ref.watch(authStateChangesProvider).value?.uid));

/// The role this person asked for at sign-up that the Admin has not decided on.
final ownPendingRoleRequestProvider = Provider<UserRole?>((ref) {
  final data = ref.watch(userProfileProvider).value;
  final access = ref.watch(userRoleProvider).value ?? UserAccess.member;
  return pendingRoleRequest(data, access);
});
