import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../models/role_request.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  /// Throws [FirebaseAuthException] on failure so the caller can show a
  /// specific message (wrong password, email already in use, etc.).
  ///
  /// New accounts are always created with the `member` role — elevated roles
  /// must be granted by an admin (enforced by security rules). A person can name
  /// the role they hold in the church as [requestedRole]; that is only a note for
  /// the Admin to approve and grants no access by itself.
  Future<User?> signUp(String email, String password, String name,
      {UserRole? requestedRole}) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      await _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
        'email': user.email,
        'name': name,
        'role': 'member',
        if (requestedRole != null && requestableRoles.contains(requestedRole))
          'requestedRole': requestedRole.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName(name);
    }
    return user;
  }

  /// The roles recorded on a profile (a plain member if there is none yet).
  Future<UserAccess> loadAccess(String uid) async {
    final doc =
        await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    return UserAccess.fromData(doc.data());
  }

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  /// Emails a password-reset link. Throws [FirebaseAuthException] for a
  /// malformed address; an unknown address is not reported, so the screen can't
  /// be used to discover which emails have accounts.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
