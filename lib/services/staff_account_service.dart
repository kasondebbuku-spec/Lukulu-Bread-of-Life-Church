import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/constants/firestore_collections.dart';
import '../core/providers/user_role_provider.dart';

/// Creates the sign-in login for a person and their starting `member` profile,
/// returning the new user's id. Kept separate so it can be replaced in tests.
typedef CreateLogin = Future<String> Function(
    String email, String temporaryPassword, String name);

/// Writes the roles onto a user's profile (an Admin-only change in the rules).
typedef GrantRoles = Future<void> Function(String uid, List<String> roles);

/// Lets an Admin set up an account for a leader, finance officer or pastor.
///
/// The Admin never knows the password: a long random one is set that nobody
/// sees, and the person is emailed a link to choose their own. Roles are then
/// granted through the same Admin-only rule as the Account Roles screen, so the
/// security rules are unchanged (no one can give themselves a role).
class StaffAccountService {
  StaffAccountService({
    required GrantRoles grantRoles,
    required Future<void> Function(String email) sendPasswordReset,
    CreateLogin? createLogin,
    Random? random,
  })  : _grantRoles = grantRoles,
        _sendPasswordReset = sendPasswordReset,
        _createLogin = createLogin ?? createLoginOnSecondaryApp,
        _random = random ?? Random.secure();

  final GrantRoles _grantRoles;
  final Future<void> Function(String email) _sendPasswordReset;
  final CreateLogin _createLogin;
  final Random _random;

  static const _alphabet =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%*-_';

  /// 24 random characters, always containing a letter and a digit.
  String temporaryPassword() {
    final chars = List.generate(
        24, (_) => _alphabet[_random.nextInt(_alphabet.length)]);
    chars[0] = 'Aa'[_random.nextInt(2)];
    chars[1] = '${2 + _random.nextInt(8)}';
    return chars.join();
  }

  /// Throws [ArgumentError] for a bad name/email/role list and lets
  /// [FirebaseAuthException] through (e.g. `email-already-in-use`).
  ///
  /// If the account is created but granting roles fails, the person exists as a
  /// plain member and the Admin can finish in Account Roles; a
  /// [StaffRolesNotGranted] is thrown so the screen can say so.
  Future<void> createStaff({
    required String name,
    required String email,
    required Set<UserRole> roles,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final granted = roles.where((r) => r != UserRole.member).toSet();
    if (cleanName.isEmpty) throw ArgumentError('Enter the person\'s name.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (granted.isEmpty) throw ArgumentError('Choose at least one role.');

    final uid = await _createLogin(cleanEmail, temporaryPassword(), cleanName);
    try {
      await _grantRoles(uid, granted.map((r) => r.name).toList());
      await _sendPasswordReset(cleanEmail);
    } catch (_) {
      throw StaffRolesNotGranted(cleanEmail);
    }
  }
}

/// The login exists but roles or the set-password email did not go through.
class StaffRolesNotGranted implements Exception {
  const StaffRolesNotGranted(this.email);
  final String email;
}

/// Signs the new person up on a short-lived second Firebase app so the Admin
/// stays signed in on the main one, then discards that app.
Future<String> createLoginOnSecondaryApp(
    String email, String temporaryPassword, String name) async {
  final app = await Firebase.initializeApp(
    name: 'staff-setup-${DateTime.now().microsecondsSinceEpoch}',
    options: Firebase.app().options,
  );
  try {
    final auth = FirebaseAuth.instanceFor(app: app);
    final credential = await auth.createUserWithEmailAndPassword(
        email: email, password: temporaryPassword);
    final user = credential.user!;
    // Same starting profile as self-registration; the rules insist on `member`.
    await FirebaseFirestore.instanceFor(app: app)
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .set({
      'email': user.email,
      'name': name,
      'role': 'member',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await user.updateDisplayName(name);
    await auth.signOut();
    return user.uid;
  } finally {
    await app.delete();
  }
}
