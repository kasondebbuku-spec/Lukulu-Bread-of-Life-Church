import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/providers/user_role_provider.dart';
import '../models/announcement.dart';

class AnnouncementsRepository {
  AnnouncementsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('announcements');

  /// Leaders (admin/secretariat/pastor) see everything; everyone else only
  /// sees 'all' audience posts — enforced server-side, not just cosmetically.
  Stream<List<Announcement>> watchAll(UserRole role) {
    Query<Map<String, dynamic>> query = _col;
    if (!role.canPostAnnouncements) {
      query = query.where('targetAudience', isEqualTo: 'all');
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Announcement.fromDoc).toList());
  }

  Future<void> add(Announcement announcement) => _col.add(announcement.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
