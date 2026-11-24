import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/pledge.dart';

class PledgeRepository extends FirestoreRepository<Pledge> {
  PledgeRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.pledges);

  @override
  Pledge fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => Pledge.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(Pledge pledge) => pledge.toMap();

  static List<Pledge> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Pledge.fromDoc).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// One member's own pledges, soonest due first.
  Stream<List<Pledge>> watchForUser(String uid) =>
      col.where('userId', isEqualTo: uid).snapshots().map(_sorted);

  /// Everyone's pledges (for those who may see giving), soonest due first.
  Stream<List<Pledge>> watchEveryone() => col.snapshots().map(_sorted);

  /// Changes the amount, due date or note. Who it is for and when it was made
  /// cannot change.
  Future<void> change(String id,
          {required double amount, required DateTime dueDate, required String note}) =>
      col.doc(id).update({
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'note': note,
      });

  Future<void> cancel(String id) => col.doc(id).update({'status': 'cancelled'});
}
