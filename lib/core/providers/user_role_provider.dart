import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

enum UserRole { member, deacon, deaconess, elder, pastor, finance, secretariat, admin }

extension UserRoleX on UserRole {
  static UserRole fromString(String? raw) => UserRole.values.firstWhere(
        (r) => r.name == raw,
        orElse: () => UserRole.member,
      );

  String get label {
    switch (this) {
      case UserRole.member:
        return 'Member';
      case UserRole.deacon:
        return 'Deacon';
      case UserRole.deaconess:
        return 'Deaconess';
      case UserRole.elder:
        return 'Elder';
      case UserRole.pastor:
        return 'Pastor';
      case UserRole.finance:
        return 'Finance Officer';
      case UserRole.secretariat:
        return 'Secretariat';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Elders, deacons, deaconesses and the pastor share the same
  /// congregational-leadership tier (moderation, not administration).
  bool get isLeadershipTier =>
      this == UserRole.elder ||
      this == UserRole.deacon ||
      this == UserRole.deaconess ||
      this == UserRole.pastor;

  bool get canManageMembers => this == UserRole.admin || this == UserRole.secretariat;

  /// Financial records are sensitive — only Admin and the Finance department
  /// can see or manage them, regardless of other leadership seniority.
  bool get canManageGiving => this == UserRole.admin || this == UserRole.finance;

  bool get canManageAttendance =>
      this == UserRole.admin || this == UserRole.secretariat || isLeadershipTier;
  bool get canManageEvents => this == UserRole.admin || this == UserRole.secretariat;
  bool get canPostAnnouncements =>
      this == UserRole.admin || this == UserRole.secretariat || isLeadershipTier;
  bool get canSeeAllPrayerRequests =>
      this == UserRole.admin || this == UserRole.secretariat || isLeadershipTier;
}

/// Streams the current user's role from Firestore, re-evaluating whenever
/// auth state changes (login/logout) or the role document itself changes.
final userRoleProvider = StreamProvider<UserRole>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;
  if (user == null) return Stream.value(UserRole.member);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => UserRoleX.fromString(doc.data()?['role'] as String?));
});
