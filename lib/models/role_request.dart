import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/providers/user_role_provider.dart';

/// Roles a person may ask for, when they sign up or later. Admin is never
/// requestable, and a request grants nothing until an Admin approves it. A person
/// may serve in several (an Elder who is also in Finance and the Secretariat) and
/// gets everything their approved roles allow, all at once.
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

/// Roles that open the church's money records, so an Admin can think twice.
bool opensFinances(UserRole role) =>
    role == UserRole.finance || role == UserRole.oversight || role == UserRole.pastor;

/// The roles a profile should hold once [requested] is approved: what they
/// already have, plus the request, without the placeholder `member`.
List<String> rolesAfterApproval(Set<UserRole> current, UserRole requested) {
  final roles = {...current, requested}..remove(UserRole.member);
  return roles.map((r) => r.name).toList();
}

/// The roles a profile is waiting on (none held yet), in a fixed order.
///
/// Reads `requestedRoles`, and the single `requestedRole` written before several
/// could be asked for.
List<UserRole> pendingRoleRequests(Map<String, dynamic>? data, UserAccess access) {
  final many = data?['requestedRoles'];
  final one = data?['requestedRole'];
  final asked = <String>{
    if (many is List) ...many.whereType<String>(),
    if (one is String) one,
  };
  return [
    for (final role in requestableRoles)
      if (asked.contains(role.name) && !access.roles.contains(role)) role,
  ];
}

/// What to write when an Admin approves or declines one requested role. Any other
/// requests the person made stay waiting.
Map<String, Object?> roleDecisionUpdate(
  Map<String, dynamic>? data,
  UserRole role, {
  required bool approve,
}) {
  final access = UserAccess.fromData(data);
  final after = approve ? UserAccess({...access.roles, role}) : access;
  final waiting = [
    for (final r in pendingRoleRequests(data, after))
      if (r != role) r.name,
  ];
  return {
    if (approve) 'roles': rolesAfterApproval(access.roles, role),
    'requestedRoles': waiting.isEmpty ? FieldValue.delete() : waiting,
    'requestedRole': FieldValue.delete(),
  };
}

/// `Elder`, `Elder and Deacon`, or `Elder, Deacon and Secretariat`.
String inWords(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
