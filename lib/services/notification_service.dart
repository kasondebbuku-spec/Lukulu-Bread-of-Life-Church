import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';

/// Remembers, on the person's own profile, when they last opened their
/// notifications, so the unread count follows them across phone and computer.
class NotificationService {
  NotificationService(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String? _uid;

  Future<void> markAllSeen() async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .update({'notificationsSeenAt': FieldValue.serverTimestamp()});
  }
}
