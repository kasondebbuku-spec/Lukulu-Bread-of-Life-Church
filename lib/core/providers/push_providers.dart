import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/push_service.dart';
import '../push/firebase_push_gateway.dart';
import '../push/push_config.dart';
import 'firebase_providers.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService(
      gateway: FirebasePushGateway(),
      firestore: ref.watch(firestoreProvider),
      vapidKey: pushVapidKey,
    ));

/// Signs out, first taking this device off the notification list so the next
/// person to use the phone does not receive the previous person's alerts.
final signOutProvider = Provider<Future<void> Function()>((ref) => () async {
      try {
        await ref
            .read(pushServiceProvider)
            .forgetDevice()
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Never stop someone signing out.
      }
      await ref.read(firebaseAuthProvider).signOut();
    });
