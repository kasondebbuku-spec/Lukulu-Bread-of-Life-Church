import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/ministry_position.dart';

/// Ministry positions on a person's profile. A person can only *ask* for a
/// position (`requestedPosition`); an Admin approves it into `positions`, which
/// is what lets them send reports to the Pastor.
class PositionService {
  PositionService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);

  /// The person asking for a position (allowed on their own profile).
  Future<void> request(String uid, MinistryPosition position) =>
      _user(uid).update({'requestedPosition': position.toMap()});

  /// An Admin approving: the position is added and the request cleared.
  Future<void> approve(String uid, MinistryPosition position) => _user(uid).update({
        'positions.${position.key}': position.toMap(),
        'requestedPosition': FieldValue.delete(),
      });

  Future<void> decline(String uid) =>
      _user(uid).update({'requestedPosition': FieldValue.delete()});

  /// An Admin replacing the whole set (to take a position away).
  Future<void> setPositions(String uid, Map<String, MinistryPosition> positions) =>
      _user(uid).update({
        'positions': {for (final e in positions.entries) e.key: e.value.toMap()},
      });
}
