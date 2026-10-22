import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// The signed-in person's own profile record (null when signed out).
final userProfileProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});
