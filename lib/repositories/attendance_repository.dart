import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_record.dart';

class AttendanceRepository {
  AttendanceRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('attendance');

  Stream<List<AttendanceRecord>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AttendanceRecord.fromDoc).toList());

  Future<void> add(AttendanceRecord record) => _col.add(record.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
