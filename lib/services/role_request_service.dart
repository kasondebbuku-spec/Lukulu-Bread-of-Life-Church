import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../models/role_request.dart';

/// Asking for church roles, and the Admin's decision on each one.
class RoleRequestService {
  RoleRequestService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);

  /// A signed-in person asking for more roles (allowed on their own profile; it
  /// grants nothing until an Admin approves).
  Future<void> ask(String uid, Set<UserRole> roles) => _user(uid).update({
        'requestedRoles': FieldValue.arrayUnion([
          for (final r in requestableRoles)
            if (roles.contains(r)) r.name,
        ]),
      });

  Future<void> approve(String uid, UserRole requested) =>
      _decide(uid, requested, approve: true);

  Future<void> decline(String uid, UserRole requested) =>
      _decide(uid, requested, approve: false);

  /// Reads the profile and writes the decision in one transaction, so approving
  /// two roles quickly can never lose the first.
  Future<void> _decide(String uid, UserRole role, {required bool approve}) =>
      _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(_user(uid));
        transaction.update(
            _user(uid), roleDecisionUpdate(doc.data(), role, approve: approve));
      });
}
