import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_role_provider.dart';

extension UserRoleAsyncValueX on AsyncValue<UserAccess> {
  UserAccess get valueOrMember =>
      maybeWhen(data: (role) => role, orElse: () => UserAccess.member);

  bool get canManageMembers => valueOrMember.canManageMembers;
  bool get canManageGiving => valueOrMember.canManageGiving;
  bool get canManageAttendance => valueOrMember.canManageAttendance;
  bool get canManageEvents => valueOrMember.canManageEvents;
  bool get canPostAnnouncements => valueOrMember.canPostAnnouncements;
  bool get canSeeAllPrayerRequests => valueOrMember.canSeeAllPrayerRequests;
}
