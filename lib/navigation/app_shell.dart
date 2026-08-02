import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/user_role_provider.dart';
import '../features/announcements/screens/announcements_screen.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/giving/screens/giving_screen.dart';
import '../features/members/screens/members_screen.dart';
import '../features/prayer/screens/prayer_screen.dart';
import 'more_screen.dart';
import 'nav_destination.dart';

const _wideBreakpoint = 600.0;

List<NavDestination> _destinationsForRole(UserRole role) {
  final home = NavDestination(
    label: 'Home',
    icon: Icons.home,
    builder: () => const DashboardScreen(),
  );
  final members = NavDestination(
    label: 'Members',
    icon: Icons.people,
    builder: () => const MembersScreen(),
  );
  final giving = NavDestination(
    label: 'Giving',
    icon: Icons.account_balance_wallet,
    builder: () => const GivingScreen(),
  );
  final attendance = NavDestination(
    label: 'Attendance',
    icon: Icons.how_to_reg,
    builder: () => const AttendanceScreen(),
  );
  final events = NavDestination(
    label: 'Events',
    icon: Icons.event,
    builder: () => const EventsScreen(),
  );
  final announcements = NavDestination(
    label: 'Announcements',
    icon: Icons.campaign,
    builder: () => const AnnouncementsScreen(),
  );
  final prayer = NavDestination(
    label: 'Prayer',
    icon: Icons.volunteer_activism,
    builder: () => const PrayerScreen(),
  );

  switch (role) {
    case UserRole.member:
      return [home, events, announcements, prayer];
    case UserRole.deacon:
    case UserRole.deaconess:
    case UserRole.elder:
    case UserRole.pastor:
      return [home, attendance, events, announcements, prayer];
    case UserRole.finance:
      return [home, giving, events, announcements, prayer];
    case UserRole.secretariat:
    case UserRole.admin:
      return [home, members, giving, attendance, events, announcements, prayer];
  }
}

/// Persistent navigation shell: bottom nav bar on phones, a side rail on
/// wider screens. Destinations are derived from the current user's role.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    return roleAsync.when(
      data: (role) => _buildShell(context, role),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Widget _buildShell(BuildContext context, UserRole role) {
    final allDestinations = _destinationsForRole(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          final index = _selectedIndex.clamp(0, allDestinations.length - 1);
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: allDestinations
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: allDestinations[index].builder()),
              ],
            ),
          );
        }

        // Narrow layout: cap the bottom bar at 5 items, tuck the rest under "More".
        final overflowing = allDestinations.length > 5;
        final barDestinations = overflowing
            ? allDestinations.take(4).toList()
            : allDestinations;
        final moreDestinations =
            overflowing ? allDestinations.skip(4).toList() : const <NavDestination>[];

        final barLength = barDestinations.length + (overflowing ? 1 : 0);
        final index = _selectedIndex.clamp(0, barLength - 1);
        final isMoreTab = overflowing && index == barDestinations.length;

        return Scaffold(
          body: isMoreTab
              ? MoreScreen(destinations: moreDestinations)
              : barDestinations[index].builder(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: [
              ...barDestinations.map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  )),
              if (overflowing)
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
            ],
          ),
        );
      },
    );
  }
}
