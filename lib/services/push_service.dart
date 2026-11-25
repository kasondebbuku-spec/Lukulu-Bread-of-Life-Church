import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether the browser/phone lets this app show notifications.
enum PushPermission { granted, denied, undetermined }

/// What the person sees: can they turn alerts on for this device, and are they on.
enum PushState {
  /// The Web Push key has not been set up yet, so the feature is hidden.
  notConfigured,

  /// This browser cannot show notifications (on iPhone: the app must be added to
  /// the Home Screen first).
  unsupported,

  /// The person said no in the browser; only the browser's settings can undo it.
  blocked,
  off,
  on,
}

/// The browser/phone side of notifications, kept behind an interface so the rest
/// can be tested without a browser. See `FirebasePushGateway`.
abstract class PushGateway {
  Future<bool> isSupported();
  Future<PushPermission> permission();

  /// Shows the browser's "Allow notifications?" prompt. Must be called from a tap.
  Future<PushPermission> requestPermission();

  /// This device's address for notifications, or null if it cannot get one.
  Future<String?> token(String vapidKey);
  Future<void> deleteToken();
}

/// Turns alerts on and off for the device in your hand.
///
/// A device is registered by writing its token to `push_tokens/{token}` with the
/// signed-in person's id; the server reads that to know where to send. Nothing is
/// sent to a device unless the person tapped "Turn on" and allowed it in the
/// browser.
class PushService {
  PushService({
    required PushGateway gateway,
    required FirebaseFirestore firestore,
    required String vapidKey,
  })  : _gateway = gateway,
        _firestore = firestore,
        _vapidKey = vapidKey;

  final PushGateway _gateway;
  final FirebaseFirestore _firestore;
  final String _vapidKey;

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('push_tokens');

  /// Where things stand for [uid] on this device, without asking for anything.
  Future<PushState> state(String uid) async {
    if (_vapidKey.isEmpty) return PushState.notConfigured;
    if (!await _gateway.isSupported()) return PushState.unsupported;
    switch (await _gateway.permission()) {
      case PushPermission.denied:
        return PushState.blocked;
      case PushPermission.undetermined:
        return PushState.off;
      case PushPermission.granted:
        break;
    }
    final token = await _gateway.token(_vapidKey);
    if (token == null) return PushState.off;
    final doc = await _tokens.doc(token).get();
    return doc.exists && doc.data()?['uid'] == uid ? PushState.on : PushState.off;
  }

  /// Asks permission if needed, then registers this device for [uid].
  Future<PushState> enable(String uid) async {
    if (_vapidKey.isEmpty) return PushState.notConfigured;
    if (!await _gateway.isSupported()) return PushState.unsupported;
    var permission = await _gateway.permission();
    if (permission == PushPermission.undetermined) {
      permission = await _gateway.requestPermission();
    }
    if (permission == PushPermission.denied) return PushState.blocked;
    if (permission != PushPermission.granted) return PushState.off;
    final token = await _gateway.token(_vapidKey);
    if (token == null) return PushState.off;
    await _tokens.doc(token).set({
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return PushState.on;
  }

  /// Stops alerts on this device: removes it from the list and forgets its address.
  Future<void> disable() async {
    if (_vapidKey.isEmpty || !await _gateway.isSupported()) return;
    if (await _gateway.permission() == PushPermission.granted) {
      final token = await _gateway.token(_vapidKey);
      if (token != null) await _tokens.doc(token).delete();
    }
    await _gateway.deleteToken();
  }

  /// Called when someone signs out, so the next person to use this phone does not
  /// receive their alerts. Never fails and never prompts.
  Future<void> forgetDevice() async {
    try {
      await disable();
    } catch (_) {
      // Signing out must not be blocked by this.
    }
  }
}
