import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/church_event.dart';

class EventsRepository {
  EventsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('events');

  /// Soonest event first — this screen is "Upcoming Events", not a feed of
  /// most-recently-added events, so it sorts by the event's own date.
  Stream<List<ChurchEvent>> watchAll() => _col
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(ChurchEvent.fromDoc).toList());

  Future<void> add(ChurchEvent event) => _col.add(event.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
