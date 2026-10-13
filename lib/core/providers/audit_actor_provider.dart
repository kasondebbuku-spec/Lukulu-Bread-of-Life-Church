import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audit_entry.dart';
import 'display_name_provider.dart';
import 'firebase_providers.dart';

/// The signed-in user as an [AuditActor], or null when nobody is signed in.
final auditActorProvider = Provider<AuditActor?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  return AuditActor(uid: user.uid, name: ref.watch(displayNameProvider));
});
