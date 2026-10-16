import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../models/role_request.dart';

/// An Admin's decision on a role someone asked for when signing up.
/// Both writes go through the Admin-only `users` update rule.
class RoleRequestService {
  RoleRequestService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);

  Future<void> approve(String uid, Set<UserRole> current, UserRole requested) =>
      _user(uid).update({
        'roles': rolesAfterApproval(current, requested),
        'requestedRole': FieldValue.delete(),
      });

  Future<void> decline(String uid) =>
      _user(uid).update({'requestedRole': FieldValue.delete()});
}
