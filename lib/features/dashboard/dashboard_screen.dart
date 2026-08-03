import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_role_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/repository_providers.dart';
import '../announcements/screens/announcements_screen.dart';
import '../attendance/screens/attendance_screen.dart';
import '../events/screens/events_screen.dart';
import '../giving/screens/giving_screen.dart';
import '../members/screens/members_screen.dart';
import '../prayer/screens/prayer_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final role = ref.watch(userRoleProvider).maybeWhen(
          data: (r) => r,
          orElse: () => UserRole.member,
        );
    final userName = user?.displayName ?? user?.email?.split('@').first ?? 'User';

    final cards = _buildCards(context, ref, role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bread of Life Lukulu Branch'),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(child: Icon(Icons.person)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(firebaseAuthProvider).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _RoleBadge(role: role),
                  ],
                ),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $userName',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            _RoleBadge(role: role),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                const spacing = 16.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                        crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context, WidgetRef ref, UserRole role) {
    final cards = <Widget>[];

    void openScreen(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }

    if (role.canManageMembers) {
      final members = ref.watch(membersProvider);
      cards.add(_DashboardCard(
        title: 'Members Directory',
        subtitle: 'Manage branch database',
        count: members.maybeWhen(data: (m) => '${m.length}', orElse: () => '…'),
        icon: Icons.people,
        accentColor: AppColors.primary,
        onTap: () => openScreen(const MembersScreen()),
      ));
    }

    if (role.canManageAttendance) {
      final attendance = ref.watch(attendanceRecordsProvider);
      cards.add(_DashboardCard(
        title: 'Attendance Tracker',
        subtitle: 'Service check-ins & data',
        count: attendance.maybeWhen(
          data: (records) =>
              records.isEmpty ? 'No data' : 'Last: ${records.first.count}',
          orElse: () => '…',
        ),
        icon: Icons.how_to_reg,
        accentColor: AppColors.blue,
        onTap: () => openScreen(const AttendanceScreen()),
      ));
    }

    if (role.canManageGiving) {
      final totalThisMonth = ref.watch(givingTotalThisMonthProvider);
      cards.add(_DashboardCard(
        title: 'Giving & Tithes',
        subtitle: 'This month\'s total',
        count: formatZmw(totalThisMonth),
        icon: Icons.account_balance_wallet,
        accentColor: AppColors.secondaryDark,
        onTap: () => openScreen(const GivingScreen()),
      ));
    }

    final events = ref.watch(eventsProvider);
    cards.add(_DashboardCard(
      title: 'Upcoming Events',
      subtitle: 'Services & church calendar',
      count: events.maybeWhen(data: (e) => '${e.length}', orElse: () => '…'),
      icon: Icons.event,
      accentColor: AppColors.blueLight,
      onTap: () => openScreen(const EventsScreen()),
    ));

    final announcements = ref.watch(announcementsProvider);
    cards.add(_DashboardCard(
      title: 'Announcements',
      subtitle: 'Broadcasts to branch app',
      count: announcements.maybeWhen(data: (a) => '${a.length}', orElse: () => '…'),
      icon: Icons.campaign,
      accentColor: AppColors.primaryLight,
      onTap: () => openScreen(const AnnouncementsScreen()),
    ));

    final prayerRequests = ref.watch(prayerRequestsProvider);
    cards.add(_DashboardCard(
      title: 'Prayer Request Wall',
      subtitle: role.canSeeAllPrayerRequests
          ? 'Review intercessory wall'
          : 'Your submitted requests',
      count: prayerRequests.maybeWhen(data: (p) => '${p.length}', orElse: () => '…'),
      icon: Icons.volunteer_activism,
      accentColor: AppColors.secondary,
      onTap: () => openScreen(const PrayerScreen()),
    ));

    return cards;
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  Color get _color {
    switch (role) {
      case UserRole.admin:
        return AppColors.secondaryDark;
      case UserRole.finance:
        return AppColors.blue;
      case UserRole.secretariat:
      case UserRole.elder:
      case UserRole.deacon:
      case UserRole.deaconess:
      case UserRole.pastor:
        return AppColors.primary;
      case UserRole.member:
        return AppColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (role) {
      case UserRole.admin:
        return Icons.shield_outlined;
      case UserRole.finance:
        return Icons.account_balance_wallet_outlined;
      case UserRole.secretariat:
        return Icons.badge_outlined;
      case UserRole.elder:
      case UserRole.deacon:
      case UserRole.deaconess:
      case UserRole.pastor:
        return Icons.church_outlined;
      case UserRole.member:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
