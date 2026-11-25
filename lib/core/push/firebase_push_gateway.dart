import 'package:firebase_messaging/firebase_messaging.dart';

import '../../services/push_service.dart';

/// The real browser/phone side of notifications, using Firebase Cloud Messaging.
class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.undetermined,
      };

  @override
  Future<bool> isSupported() => _messaging.isSupported();

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> token(String vapidKey) => _messaging.getToken(vapidKey: vapidKey);

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
