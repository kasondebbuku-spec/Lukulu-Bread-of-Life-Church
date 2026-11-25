import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ministry_position.dart';
import '../../models/ministry_report.dart';
import '../../repositories/ministry_report_repository.dart';
import '../../services/leader_directory_service.dart';
import '../../services/position_service.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';
import 'user_role_provider.dart';

final ministryReportRepositoryProvider = Provider<MinistryReportRepository>(
  (ref) => MinistryReportRepository(ref.watch(firestoreProvider)),
);

/// Reports the signed-in leader has sent.
final myMinistryReportsProvider =
    StreamProvider.autoDispose<List<MinistryReport>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(const []);
  return ref.watch(ministryReportRepositoryProvider).watchForAuthor(user.uid);
});

/// Every leader's reports, for the Pastor and Admin (empty for everyone else).
final allMinistryReportsProvider =
    StreamProvider.autoDispose<List<MinistryReport>>((ref) {
  final access = ref.watch(userRoleProvider).asData?.value;
  if (access?.canReviewMinistryReports != true) return Stream.value(const []);
  return ref.watch(ministryReportRepositoryProvider).watchAll();
});

final leaderDirectoryServiceProvider = Provider<LeaderDirectoryService>(
  (ref) => LeaderDirectoryService(ref.watch(firestoreProvider)),
);

/// The leaders directory: name and position, readable by every signed-in person.
final leadersProvider = StreamProvider.autoDispose<List<LeaderEntry>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.leaders)
      .snapshots()
      .map((s) => s.docs.map(LeaderEntry.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
});

/// Phone and email of leaders, readable only by other leaders (empty otherwise).
final leaderContactsProvider =
    StreamProvider.autoDispose<Map<String, LeaderContact>>((ref) {
  final access = ref.watch(userRoleProvider).asData?.value;
  if (access?.isLeaderAccount != true) return Stream.value(const {});
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.leaderContacts)
      .snapshots()
      .map((s) => {
            for (final d in s.docs)
              d.id: LeaderContact(
                  email: d.data()['email'] as String?,
                  phone: d.data()['phone'] as String?),
          });
});

final positionServiceProvider = Provider<PositionService>(
  (ref) => PositionService(ref.watch(firestoreProvider)),
);

/// The position the signed-in person has asked for and an Admin has not yet
/// decided on, if any.
final myPositionRequestProvider =
    StreamProvider.autoDispose<MinistryPosition?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.users)
      .doc(user.uid)
      .snapshots()
      .map((d) => MinistryPosition.fromMap(d.data()?['requestedPosition']));
});
