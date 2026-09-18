import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/announcement.dart';

class AnnouncementsRepository extends FirestoreRepository<Announcement> {
  AnnouncementsRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.announcements);

  /// Leaders (admin/secretariat/pastor) see everything; everyone else only
  /// sees 'all' audience posts — enforced server-side, not just cosmetically.
  /// Not named `watchAll` — that's the base class's no-arg method and this
  /// has an incompatible (role-filtered) signature, which Dart disallows
  /// as an override.
  Stream<List<Announcement>> watchAllForRole(UserAccess role) {
    Query<Map<String, dynamic>> query = col;
    if (!role.canPostAnnouncements) {
      query = query.where('targetAudience', isEqualTo: 'all');
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromDoc).toList());
  }

  @override
  Announcement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Announcement.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(Announcement announcement) => announcement.toMap();
}
