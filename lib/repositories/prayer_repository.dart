import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prayer_request.dart';

class PrayerRepository {
  PrayerRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('prayer_requests');

  /// Privileged roles see every request; regular members only see their own.
  Stream<List<PrayerRequest>> watchAll({
    required String? userId,
    required bool seeAll,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (!seeAll) {
      query = query.where('userId', isEqualTo: userId);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PrayerRequest.fromDoc).toList());
  }

  Future<void> add(PrayerRequest request) => _col.add(request.toMap());

  Future<void> updateStatus(String id, String status) =>
      _col.doc(id).update({'status': status});

  Future<void> delete(String id) => _col.doc(id).delete();
}
