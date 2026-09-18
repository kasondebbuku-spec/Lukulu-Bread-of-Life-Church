import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/attendance_record.dart';

class AttendanceRepository extends FirestoreRepository<AttendanceRecord> {
  AttendanceRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.attendance);

  @override
  AttendanceRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceRecord.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(AttendanceRecord record) => record.toMap();
}
