import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/staff_account_service.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// Dependency-injection provider for [AuthService] (Repository/Service pattern).
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Admin-only: sets up accounts for staff and grants their roles.
final staffAccountServiceProvider = Provider<StaffAccountService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return StaffAccountService(
    grantRoles: (uid, roles) => firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .update({'roles': roles}),
    sendPasswordReset: ref.watch(authServiceProvider).sendPasswordReset,
  );
});
