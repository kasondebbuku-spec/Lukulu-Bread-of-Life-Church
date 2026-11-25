import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../models/ministry_position.dart';
import '../models/phone_login.dart';

/// One person in the leaders directory: a church role and/or ministry positions.
class LeaderEntry {
  const LeaderEntry({
    required this.uid,
    required this.name,
    this.roles = const [],
    this.positions = const [],
  });

  final String uid;
  final String name;

  /// Church roles (Pastor, Elder, ...). Never `member` or `admin`.
  final List<UserRole> roles;
  final List<MinistryPosition> positions;

  factory LeaderEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LeaderEntry(
      uid: doc.id,
      name: d['name'] as String? ?? 'Leader',
      roles: [
        for (final r in (d['roles'] as List?) ?? const [])
          if (r is String) UserRoleX.fromString(r),
      ],
      positions: [
        for (final p in (d['positions'] as List?) ?? const [])
          if (MinistryPosition.fromMap(p) != null) MinistryPosition.fromMap(p)!,
      ],
    );
  }
}

/// Keeps the leaders directory in step with people's accounts.
///
/// Everyone may read `leaders` (name and position only); `leader_contacts` holds
/// phone and email and is readable only by other leaders. Both are copies made
/// from the private `users` profiles, and only an Admin can write them, so they
/// are refreshed whenever an Admin changes roles or positions.
class LeaderDirectoryService {
  LeaderDirectoryService(this._firestore);

  final FirebaseFirestore _firestore;

  /// What to publish for an account, or null when the person is not a leader
  /// (a plain member with no ministry position).
  static ({Map<String, dynamic> leader, Map<String, dynamic> contact})? project(
      Map<String, dynamic>? user) {
    if (user == null) return null;
    final access = UserAccess.fromData(user);
    final roles = [
      for (final r in access.roles)
        if (r != UserRole.member && r != UserRole.admin) r.name,
    ]..sort();
    final positions = [for (final p in access.positions.values) p.toMap()];
    if (roles.isEmpty && positions.isEmpty) return null;

    final name = (user['name'] as String?)?.trim();
    final phone = user['phone'] is String ? user['phone'] as String : '';
    final rawEmail = user['email'] as String?;
    final email = isPhoneLoginEmail(rawEmail) ? '' : (rawEmail ?? '');
    return (
      leader: {
        'name': name == null || name.isEmpty ? 'Leader' : name,
        'roles': roles,
        'positions': positions,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      contact: {
        if (email.isNotEmpty) 'email': email,
        if (phone.isNotEmpty) 'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  void _stage(WriteBatch batch, String uid, Map<String, dynamic>? user) {
    final leader = _firestore.collection(FirestoreCollections.leaders).doc(uid);
    final contact = _firestore.collection(FirestoreCollections.leaderContacts).doc(uid);
    final p = project(user);
    if (p == null) {
      batch.delete(leader);
      batch.delete(contact);
      return;
    }
    batch.set(leader, p.leader);
    if (p.contact.length > 1) {
      batch.set(contact, p.contact);
    } else {
      batch.delete(contact);
    }
  }

  /// Re-publishes one person after an Admin changed their roles or positions.
  Future<void> syncFor(String uid) async {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    final batch = _firestore.batch();
    _stage(batch, uid, doc.data());
    await batch.commit();
  }

  /// Rebuilds the whole directory from the accounts (for people who were given
  /// a role before the directory existed). Returns how many leaders it lists.
  Future<int> rebuild() async {
    final users = await _firestore.collection(FirestoreCollections.users).get();
    var leaders = 0;
    for (var i = 0; i < users.docs.length; i += 200) {
      final batch = _firestore.batch();
      for (final doc in users.docs.skip(i).take(200)) {
        _stage(batch, doc.id, doc.data());
        if (project(doc.data()) != null) leaders++;
      }
      await batch.commit();
    }
    return leaders;
  }
}
