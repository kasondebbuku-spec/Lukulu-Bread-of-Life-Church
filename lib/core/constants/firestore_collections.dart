/// Central registry of Firestore collection paths — single source of truth
/// for both repositories and security-rule documentation.
abstract final class FirestoreCollections {
  static const users = 'users';
  static const members = 'members';
  static const giving = 'giving';
  static const incomeForms = 'income_forms';
  static const attendance = 'attendance';
  static const events = 'events';
  static const announcements = 'announcements';
  static const prayerRequests = 'prayer_requests';
}
