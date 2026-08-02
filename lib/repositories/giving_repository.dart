import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/giving_record.dart';

class GivingRepository {
  GivingRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('giving');

  Stream<List<GivingRecord>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(GivingRecord.fromDoc).toList());

  Future<void> add(GivingRecord record) => _col.add(record.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
