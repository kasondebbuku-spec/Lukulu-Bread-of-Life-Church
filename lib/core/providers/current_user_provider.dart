import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// The signed-in user's id, or null when nobody is signed in.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateChangesProvider).value?.uid,
);
