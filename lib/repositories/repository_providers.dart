import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';
import '../core/providers/user_role_provider.dart';
import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/church_event.dart';
import '../models/giving_record.dart';
import '../models/member.dart';
import '../models/prayer_request.dart';
import '../models/sunday_income_form.dart';
import '../models/week_summary.dart';
import 'announcements_repository.dart';
import 'attendance_repository.dart';
import 'events_repository.dart';
import 'giving_repository.dart';
import 'income_form_repository.dart';
import 'members_repository.dart';
import 'prayer_repository.dart';

// Members
final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepository(ref.watch(firestoreProvider)),
);
final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref.watch(membersRepositoryProvider).watchAll(),
);

// Giving
final givingRepositoryProvider = Provider<GivingRepository>(
  (ref) => GivingRepository(ref.watch(firestoreProvider)),
);
final givingRecordsProvider = StreamProvider<List<GivingRecord>>(
  (ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final access = ref.watch(userRoleProvider).value;
    if (user == null || access?.canViewGiving != true) return Stream.value([]);
    return ref.watch(givingRepositoryProvider).watchAll();
  },
);

final myGivingProvider = StreamProvider.autoDispose<List<GivingRecord>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(givingRepositoryProvider).watchForMember(user.uid);
});
final givingTotalAllTimeProvider = Provider<double>((ref) {
  return ref.watch(givingRecordsProvider).maybeWhen(
        data: (records) => records
            .where((r) => r.currency == 'ZMW')
            .fold<double>(0, (sum, r) => sum + r.amount),
        orElse: () => 0,
      );
});
final givingTotalThisMonthProvider = Provider<double>((ref) {
  final now = ref.watch(dashboardClockProvider).value ?? DateTime.now();
  return ref.watch(givingRecordsProvider).maybeWhen(
        data: (records) => records
            .where((r) =>
                r.currency == 'ZMW' &&
                r.date.year == now.year &&
                r.date.month == now.month)
            .fold<double>(0, (sum, r) => sum + r.amount),
        orElse: () => 0,
      );
});
final weekSummaryProvider =
    Provider.family<WeekSummary, DateTime>((ref, sunday) {
  final records = ref.watch(givingRecordsProvider).maybeWhen(
        data: (r) => r,
        orElse: () => <GivingRecord>[],
      );
  return WeekSummary.compute(
      sunday, records.where((r) => r.currency == 'ZMW').toList());
});

// Sunday Income Forms
final incomeFormRepositoryProvider = Provider<IncomeFormRepository>(
  (ref) => IncomeFormRepository(ref.watch(firestoreProvider)),
);
final incomeFormsProvider = StreamProvider<List<SundayIncomeForm>>(
  (ref) => ref.watch(incomeFormRepositoryProvider).watchAll(),
);

// Attendance
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref.watch(firestoreProvider)),
);
final attendanceRecordsProvider = StreamProvider<List<AttendanceRecord>>(
  (ref) => ref.watch(attendanceRepositoryProvider).watchAll(),
);

// Events
final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(firestoreProvider)),
);
final eventsProvider = StreamProvider<List<ChurchEvent>>(
  (ref) => ref.watch(eventsRepositoryProvider).watchAll(),
);

/// Refresh date-dependent summaries even when no database record changes.
final dashboardClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

final upcomingEventsProvider = Provider<AsyncValue<List<ChurchEvent>>>((ref) {
  final now = ref.watch(dashboardClockProvider).value ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref.watch(eventsProvider).whenData((events) {
    final upcoming =
        events.where((event) => !event.date.isBefore(today)).toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  });
});

// Announcements
final announcementsRepositoryProvider = Provider<AnnouncementsRepository>(
  (ref) => AnnouncementsRepository(ref.watch(firestoreProvider)),
);
final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final role = ref.watch(userRoleProvider).value ?? UserAccess.member;
  return ref.watch(announcementsRepositoryProvider).watchAllForRole(role);
});

// Prayer
final prayerRepositoryProvider = Provider<PrayerRepository>(
  (ref) => PrayerRepository(ref.watch(firestoreProvider)),
);
final prayerRequestsProvider = StreamProvider<List<PrayerRequest>>((ref) {
  final role = ref.watch(userRoleProvider).value ?? UserAccess.member;
  final user = ref.watch(authStateChangesProvider).value;
  return ref.watch(prayerRepositoryProvider).watchFiltered(
        userId: user?.uid,
        seeAll: role.canSeeAllPrayerRequests,
      );
});
