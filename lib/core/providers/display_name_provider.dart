import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/phone_login.dart';
import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

/// Best name to show for the signed-in user: the profile name saved at signup,
/// then the auth display name, then a tidied-up version of the email prefix.
/// Someone who signed up with a phone number has a made-up email, which is never
/// shown as their name.
String displayNameFor({
  String? profileName,
  String? authDisplayName,
  String? email,
}) {
  for (final candidate in [profileName, authDisplayName]) {
    if (candidate != null && candidate.trim().isNotEmpty) return candidate.trim();
  }
  final prefix = isPhoneLoginEmail(email) ? '' : (email ?? '').split('@').first;
  final words = prefix.split(RegExp(r'[._\-]+')).where((w) => w.isNotEmpty);
  final tidy = words
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  return tidy.isEmpty ? 'User' : tidy;
}

final userProfileNameProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['name'] as String?);
});

final displayNameProvider = Provider<String>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  return displayNameFor(
    // `valueOrNull`: if the profile cannot be loaded, carry on with what we have.
    profileName: ref.watch(userProfileNameProvider).valueOrNull,
    authDisplayName: user?.displayName,
    email: user?.email,
  );
});
