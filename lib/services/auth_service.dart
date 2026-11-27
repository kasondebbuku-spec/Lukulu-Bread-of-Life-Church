import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';
import '../models/ministry_position.dart';
import '../models/phone_login.dart';
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
  /// the roles they hold in the church as [requestedRoles]; that is only a note for
  /// the Admin to approve and grants no access by itself.
  ///
  /// With [phone] (digits from [normalizePhone]) the account is made under the
  /// private address [phoneLoginEmail] instead of a real email, and the number is
  /// kept on the profile. [requestedPosition] is a ministry position to be
  /// approved by the Admin, like [requestedRoles].
  Future<User?> signUp(String email, String password, String name,
      {Set<UserRole> requestedRoles = const {},
      MinistryPosition? requestedPosition,
      String? phone}) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: phone != null ? phoneLoginEmail(phone) : email,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      await _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
        'email': user.email,
        'name': name,
        'role': 'member',
        if (phone != null) 'phone': phone,
        if (phone != null) 'loginKind': 'phone',
        if (requestableRoles.any(requestedRoles.contains))
          'requestedRoles': [
            for (final r in requestableRoles)
              if (requestedRoles.contains(r)) r.name,
          ],
        if (requestedPosition != null)
          'requestedPosition': requestedPosition.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName(name);
    }
    return user;
  }

  /// [identifier] is an email, or a phone number (anything [looksLikePhone]).
  Future<User?> signIn(String identifier, String password) async {
    final phone = looksLikePhone(identifier) ? normalizePhone(identifier) : null;
    final result = await _auth.signInWithEmailAndPassword(
      email: phone != null ? phoneLoginEmail(phone) : identifier,
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

  /// Changes the signed-in person's password. The current one is checked first,
  /// so someone who picks up an unlocked phone cannot change it. Throws
  /// [FirebaseAuthException] (`wrong-password` / `invalid-credential` when the
  /// current password is wrong).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword));
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
