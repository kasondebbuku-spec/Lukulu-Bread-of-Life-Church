import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/giving/zmw_denominations.dart';
import '../../models/app_notification.dart';
import '../../models/pledge.dart';
import '../../models/sunday_income_form.dart';
import '../../models/role_request.dart';
import '../../repositories/repository_providers.dart';
import '../../services/notification_service.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import 'firebase_providers.dart';
import 'pledge_providers.dart';
import 'user_profile_provider.dart';
import 'user_role_provider.dart';

/// Recent announcements and new events, newest first.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final announcements = ref.watch(announcementsProvider).value ?? const [];
  final events = ref.watch(eventsProvider).value ?? const [];

  // People who may see giving are told when a Sunday income form is saved,
  // except by themselves (they know). Everyone else never reads those forms.
  final role = ref.watch(userRoleProvider).value ?? UserAccess.member;
  final myUid = ref.watch(authStateChangesProvider).value?.uid;
  final values = {for (final d in zmwDenominations) d.key: d.value};
  final formNotices = !role.canViewGiving
      ? const <AppNotification>[]
      : [
          for (final f in ref.watch(incomeFormsProvider).value ?? const <SundayIncomeForm>[])
            if (f.createdAt != null && (myUid == null || f.enteredByUid != myUid))
              AppNotification(
                kind: NotificationKind.incomeForm,
                title: 'Sunday Income Form saved',
                detail: '${formatDate(f.date)} ${f.service.label}'
                    ' - Grand Total ${formatZmw(f.grandTotal(values))}'
                    '${f.enteredByLabel.isEmpty ? '' : ', entered by ${f.enteredByLabel}'}',
                at: f.createdAt!,
              ),
        ];

  // A member is reminded about their own pledges that are due within a week or
  // late: the first reminder dates from a week before the due date, the second
  // from the due date itself.
  final pledgeNotices = [
    for (final p in ref.watch(myPledgeProgressProvider))
      if (p.needsReminder)
        AppNotification(
          kind: NotificationKind.pledge,
          title: 'Pledge reminder',
          detail: p.reminderText(),
          at: p.state == PledgeState.overdue
              ? p.pledge.dueDate
              : p.pledge.dueDate.subtract(const Duration(days: pledgeReminderLeadDays)),
        ),
  ];

  return buildNotifications(
      announcements: announcements,
      events: events,
      now: DateTime.now(),
      extra: [...formNotices, ...pledgeNotices]);
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
