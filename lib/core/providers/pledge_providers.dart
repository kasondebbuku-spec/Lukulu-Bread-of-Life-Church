import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/giving_record.dart';
import '../../models/pledge.dart';
import '../../repositories/pledge_repository.dart';
import '../../repositories/repository_providers.dart';
import 'firebase_providers.dart';
import 'user_role_provider.dart';

final pledgeRepositoryProvider = Provider<PledgeRepository>(
  (ref) => PledgeRepository(ref.watch(firestoreProvider)),
);

/// The signed-in member's own pledges.
final myPledgesProvider = StreamProvider.autoDispose<List<Pledge>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(pledgeRepositoryProvider).watchForUser(user.uid);
});

/// Everyone's pledges, for those who may see giving (empty for everyone else).
final allPledgesProvider = StreamProvider.autoDispose<List<Pledge>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  final access = ref.watch(userRoleProvider).value;
  if (user == null || access?.canViewGiving != true) return Stream.value(const []);
  return ref.watch(pledgeRepositoryProvider).watchEveryone();
});

/// The signed-in member's pledges with what they have given towards each.
/// Payments are the Pledge-category giving linked to their account.
final myPledgeProgressProvider = Provider.autoDispose<List<PledgeProgress>>((ref) {
  final pledges = ref.watch(myPledgesProvider).value ?? const <Pledge>[];
  final given = ref.watch(myGivingProvider).value ?? const <GivingRecord>[];
  final now = ref.watch(dashboardClockProvider).value ?? DateTime.now();
  return pledgeProgress(pledges: pledges, payments: given, now: now);
});

/// Everyone's pledges with progress, for those who may see giving.
final allPledgeProgressProvider = Provider.autoDispose<List<PledgeProgress>>((ref) {
  final pledges = ref.watch(allPledgesProvider).value ?? const <Pledge>[];
  final given = ref.watch(givingRecordsProvider).value ?? const <GivingRecord>[];
  final now = ref.watch(dashboardClockProvider).value ?? DateTime.now();
  return pledgeProgress(pledges: pledges, payments: given, now: now);
});
