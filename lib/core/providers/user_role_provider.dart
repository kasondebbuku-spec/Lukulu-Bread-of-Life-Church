import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import 'firebase_providers.dart';

enum UserRole {
  member,
  deacon,
  deaconess,
  elder,
  pastor,
  finance,
  secretariat,
  hospitality,
  oversight,
  admin
}

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
      case UserRole.hospitality:
        return 'Hospitality';
      case UserRole.oversight:
        return 'Financial Oversight';
    }
  }

  /// Elders, deacons, deaconesses and the pastor share the same
  /// congregational-leadership tier (moderation, not administration).
  bool get isLeadershipTier =>
      this == UserRole.elder ||
      this == UserRole.deacon ||
      this == UserRole.deaconess ||
      this == UserRole.pastor;

  bool get canManageMembers =>
      this == UserRole.admin ||
      this == UserRole.secretariat ||
      this == UserRole.hospitality;

  /// Financial records are sensitive — only Admin and the Finance department
  /// can see or manage them, regardless of other leadership seniority.
  bool get canManageGiving =>
      this == UserRole.admin || this == UserRole.finance;
  bool get canViewGiving => canManageGiving || this == UserRole.oversight;

  bool get canManageAttendance =>
      this == UserRole.admin ||
      this == UserRole.secretariat ||
      isLeadershipTier;
  bool get canManageEvents =>
      this == UserRole.admin || this == UserRole.secretariat;
  bool get canPostAnnouncements =>
      this == UserRole.admin ||
      this == UserRole.secretariat ||
      isLeadershipTier;
  bool get canSeeAllPrayerRequests =>
      this == UserRole.admin ||
      this == UserRole.secretariat ||
      isLeadershipTier;
}

/// Multiple responsibilities; legacy profiles with a single role still work.
class UserAccess {
  const UserAccess(this.roles);
  static const member = UserAccess({UserRole.member});
  final Set<UserRole> roles;
  factory UserAccess.fromData(Map<String, dynamic>? data) {
    final raw = data?['roles'];
    if (data?.containsKey('roles') == true && raw is! List) return member;
    final legacy = data?['role'];
    final roles = raw is List
        ? raw.whereType<String>().map(UserRoleX.fromString).toSet()
        : {UserRoleX.fromString(legacy is String ? legacy : null)};
    return UserAccess(roles.isEmpty ? {UserRole.member} : roles);
  }
  String get label => roles.map((r) => r.label).join(' · ');
  bool get isAdmin => roles.contains(UserRole.admin);
  bool get canManageMembers => roles.any((r) => r.canManageMembers);
  bool get canManageGiving => roles.any((r) => r.canManageGiving);
  bool get canViewGiving => roles.any((r) => r.canViewGiving);
  bool get canManageAttendance => roles.any((r) => r.canManageAttendance);
  bool get canManageEvents => roles.any((r) => r.canManageEvents);
  bool get canPostAnnouncements => roles.any((r) => r.canPostAnnouncements);
  bool get canSeeAllPrayerRequests =>
      roles.any((r) => r.canSeeAllPrayerRequests);
}

/// Streams the current user's role from Firestore, re-evaluating whenever
/// auth state changes (login/logout) or the role document itself changes.
final userRoleProvider = StreamProvider<UserAccess>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;
  if (user == null) return Stream.value(UserAccess.member);

  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) => UserAccess.fromData(doc.data()));
});
