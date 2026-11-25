import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/ministry_report.dart';

class MinistryReportRepository extends FirestoreRepository<MinistryReport> {
  MinistryReportRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.ministryReports);

  @override
  MinistryReport fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MinistryReport.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(MinistryReport report) => report.toMap();

  static List<MinistryReport> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(MinistryReport.fromDoc).toList()
        ..sort((a, b) => b.period.compareTo(a.period));

  /// One leader's own reports, newest first.
  Stream<List<MinistryReport>> watchForAuthor(String uid) =>
      col.where('authorUid', isEqualTo: uid).snapshots().map(_newestFirst);

  /// Everyone's reports (for the Pastor and Admin), newest first.
  @override
  Stream<List<MinistryReport>> watchAll() => col.snapshots().map(_newestFirst);

  /// The author correcting a report that has not been reviewed yet.
  Future<void> change(
    String id, {
    required DateTime period,
    required int attendance,
    required String summary,
    required String challenges,
    required String needs,
  }) =>
      col.doc(id).update({
        'period': Timestamp.fromDate(period),
        'attendance': attendance,
        'summary': summary,
        'challenges': challenges,
        'needs': needs,
      });

  /// The Pastor (or Admin) marking a report as read, with an optional reply.
  Future<void> markReviewed(String id,
          {required String note, required String reviewer}) =>
      col.doc(id).update({
        'status': ReportStatus.reviewed.name,
        'pastorNote': note,
        'reviewedBy': reviewer,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
}
