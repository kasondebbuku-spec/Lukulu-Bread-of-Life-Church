import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import 'firebase_providers.dart';

/// Dependency-injection provider for [AuthService] (Repository/Service pattern).
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});
