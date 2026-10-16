import '../core/providers/user_role_provider.dart';

/// Roles a person may ask for when they sign up. Admin is never requestable,
/// and a request grants nothing until an Admin approves it.
const requestableRoles = <UserRole>[
  UserRole.pastor,
  UserRole.elder,
  UserRole.deacon,
  UserRole.deaconess,
  UserRole.finance,
  UserRole.oversight,
  UserRole.secretariat,
  UserRole.hospitality,
];

/// The roles a profile should hold once [requested] is approved: what they
/// already have, plus the request, without the placeholder `member`.
List<String> rolesAfterApproval(Set<UserRole> current, UserRole requested) {
  final roles = {...current, requested}..remove(UserRole.member);
  return roles.map((r) => r.name).toList();
}

/// The role a profile is waiting on, or null when there is nothing to decide.
UserRole? pendingRoleRequest(Map<String, dynamic>? data, UserAccess access) {
  final raw = data?['requestedRole'];
  if (raw is! String) return null;
  for (final role in requestableRoles) {
    if (role.name == raw) return access.roles.contains(role) ? null : role;
  }
  return null;
}
