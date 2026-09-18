import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';

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
  /// must be granted by an admin in Firestore (enforced by security rules).
  Future<User?> signUp(String email, String password, String name) async {
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
        'createdAt': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName(name);
    }
    return user;
  }

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
