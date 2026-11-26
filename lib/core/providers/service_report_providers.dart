import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/service_report.dart';
import '../../repositories/service_report_repository.dart';
import 'firebase_providers.dart';
import 'user_role_provider.dart';

final serviceReportRepositoryProvider = Provider<ServiceReportRepository>(
  (ref) => ServiceReportRepository(ref.watch(firestoreProvider)),
);

/// The Sunday Service Reports, newest first (empty for anyone who may not see
/// them).
final serviceReportsProvider =
    StreamProvider.autoDispose<List<ServiceReport>>((ref) {
  final access = ref.watch(userRoleProvider).asData?.value;
  if (access?.canViewServiceReports != true) return Stream.value(const []);
  return ref.watch(serviceReportRepositoryProvider).watchAll();
});
