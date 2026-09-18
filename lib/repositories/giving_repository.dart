import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/giving_record.dart';

class GivingRepository extends FirestoreRepository<GivingRecord> {
  GivingRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.giving);

  @override
  GivingRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      GivingRecord.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(GivingRecord record) => record.toMap();

  Stream<List<GivingRecord>> watchForMember(String uid) =>
      col.where('memberUserId', isEqualTo: uid).snapshots().map((snapshot) {
        final records = snapshot.docs.map(fromDoc).toList();
        records.sort((a, b) => b.date.compareTo(a.date));
        return records;
      });
}
