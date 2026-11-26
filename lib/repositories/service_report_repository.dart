import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/service_report.dart';

class ServiceReportRepository extends FirestoreRepository<ServiceReport> {
  ServiceReportRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.serviceReports);

  @override
  ServiceReport fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ServiceReport.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(ServiceReport report) => report.toMap();

  /// Newest service first.
  @override
  Stream<List<ServiceReport>> watchAll() => col
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ServiceReport.fromDoc).toList());

  /// Rewrites what was filled in, keeping who first entered it and when. A
  /// signature that was not redrawn stays as it was.
  @override
  Future<void> update(String id, ServiceReport report) => col.doc(id).update({
        ...report.toContentMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
