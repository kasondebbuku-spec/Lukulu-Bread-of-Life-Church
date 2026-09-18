import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/prayer_request.dart';

class PrayerRepository extends FirestoreRepository<PrayerRequest> {
  PrayerRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.prayerRequests);

  /// Privileged roles see every request; regular members only see their own.
  /// Not named `watchAll` — incompatible (filtered) signature vs the base
  /// class's no-arg method.
  Stream<List<PrayerRequest>> watchFiltered({
    required String? userId,
    required bool seeAll,
  }) {
    Query<Map<String, dynamic>> query = col;
    if (!seeAll) {
      query = query.where('userId', isEqualTo: userId);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromDoc).toList());
  }

  @override
  PrayerRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PrayerRequest.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(PrayerRequest request) => request.toMap();

  Future<void> updateStatus(String id, String status) =>
      col.doc(id).update({'status': status});
}
