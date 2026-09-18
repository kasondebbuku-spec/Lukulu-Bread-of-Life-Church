import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/church_event.dart';

class EventsRepository extends FirestoreRepository<ChurchEvent> {
  EventsRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.events);

  /// Soonest event first — this screen is "Upcoming Events", not a feed of
  /// most-recently-added events, so it sorts by the event's own date.
  @override
  Stream<List<ChurchEvent>> watchAll() => col
      .orderBy('date')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(fromDoc).toList());

  @override
  ChurchEvent fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ChurchEvent.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(ChurchEvent event) => event.toMap();
}
