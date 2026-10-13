import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/audit_entry.dart';

/// Read side of the activity log. Entries are immutable and are only ever
/// created inside the same batch as the change they describe (see
/// IncomeFormRepository), so this repository deliberately cannot write.
class AuditRepository extends FirestoreRepository<AuditEntry> {
  AuditRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.auditLog);

  @override
  AuditEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AuditEntry.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(AuditEntry item) => throw UnsupportedError(
      'Audit entries are written only together with the change they record.');

  /// Newest first, capped so the log stays fast as it grows.
  @override
  Stream<List<AuditEntry>> watchAll() => col
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(fromDoc).toList());
}
