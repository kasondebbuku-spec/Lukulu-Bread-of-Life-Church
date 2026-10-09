import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/daily_verses.dart';
import '../../core/constants/social_links.dart';
import '../../core/providers/display_name_provider.dart';
import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_role_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/greeting.dart';
import '../../repositories/repository_providers.dart';
import '../announcements/screens/announcements_screen.dart';
import '../attendance/screens/attendance_screen.dart';
import '../events/screens/events_screen.dart';
import '../giving/screens/giving_screen.dart';
import '../members/screens/members_screen.dart';
import '../prayer/screens/prayer_screen.dart';
import 'widgets/daily_verse_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/hero_banner.dart';
import 'widgets/quick_access_card.dart';
import 'widgets/upcoming_events_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider).maybeWhen(
          data: (r) => r,
          orElse: () => UserAccess.member,
        );
    final userName = ref.watch(displayNameProvider);

    final cards = _buildCards(context, ref, role);
    final upcoming = ref.watch(upcomingEventsProvider);
    final nextEvent = upcoming.maybeWhen(
      data: (events) => events.isEmpty ? null : events.first,
      orElse: () => null,
    );
    final now = ref.watch(dashboardClockProvider).value ?? DateTime.now();
    final firstName = userName.split(' ').first;

    void openScreen(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    final panels = <Widget>[
      UpcomingEventsCard(
          events: upcoming, onViewAll: () => openScreen(const EventsScreen())),
      QuickAccessCard(items: _quickAccess(context, role, openScreen)),
      DailyVerseCard(verse: verseForDate(now)),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(
                    greeting: '${greetingFor(now)}, $firstName',
                    userName: userName,
                    role: role,
                    onLogout: () => ref.read(firebaseAuthProvider).signOut(),
                  ),
                  const SizedBox(height: 20),
                  HeroBanner(
                    nextEvent: nextEvent,
                    onViewEvents: () => openScreen(const EventsScreen()),
                    onJoinWhatsApp: () => _openUrl(context, SocialLinks.whatsAppGroup),
                    onWatchLive: SocialLinks.hasFacebookLive
                        ? () => _openUrl(context, SocialLinks.facebookLive)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: panels[0]),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: panels[1]),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: panels[2]),
                        ],
                      );
                    }
                    return Column(children: [
                      for (final p in panels)
                        Padding(padding: const EdgeInsets.only(bottom: 16), child: p),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('Stay connected and manage your church activities.'),
                  const SizedBox(height: 20),
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
          ),
        ),
      ),
    );
  }

  List<QuickAccessItem> _quickAccess(
    BuildContext context,
    UserAccess role,
    void Function(Widget) open,
  ) {
    final all = <QuickAccessItem>[
      if (role.canViewGiving)
        QuickAccessItem(
            label: 'Giving',
            icon: Icons.account_balance_wallet,
            color: AppColors.goldInk,
            onTap: () => open(const GivingScreen())),
      if (role.canManageMembers)
        QuickAccessItem(
            label: 'Members',
            icon: Icons.people,
            color: AppColors.primary,
            onTap: () => open(const MembersScreen())),
      if (role.canManageAttendance)
        QuickAccessItem(
            label: 'Attendance',
            icon: Icons.how_to_reg,
            color: AppColors.blue,
            onTap: () => open(const AttendanceScreen())),
      QuickAccessItem(
          label: 'Events',
          icon: Icons.event,
          color: AppColors.blue,
          onTap: () => open(const EventsScreen())),
      QuickAccessItem(
          label: 'Prayer',
          icon: Icons.volunteer_activism,
          color: AppColors.primaryLight,
          onTap: () => open(const PrayerScreen())),
      QuickAccessItem(
          label: 'Announcements',
          icon: Icons.campaign,
          color: AppColors.goldInk,
          onTap: () => open(const AnnouncementsScreen())),
      QuickAccessItem(
          label: 'WhatsApp',
          icon: Icons.chat_bubble_outline,
          color: AppColors.blue,
          onTap: () => _openUrl(context, SocialLinks.whatsAppGroup)),
    ];
    return all.take(4).toList();
  }

  List<Widget> _buildCards(
      BuildContext context, WidgetRef ref, UserAccess role) {
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

    if (role.canViewGiving) {
      final giving = ref.watch(givingRecordsProvider);
      final totalThisMonth = ref.watch(givingTotalThisMonthProvider);
      cards.add(_DashboardCard(
        title: 'Giving & Tithes',
        subtitle: 'This month\'s total',
        count: giving.when(
          data: (_) => formatZmw(totalThisMonth),
          loading: () => 'Loading…',
          error: (error, stack) => 'Unavailable',
        ),
        icon: Icons.account_balance_wallet,
        accentColor: AppColors.goldInk,
        onTap: () => openScreen(const GivingScreen()),
      ));
    }

    final announcements = ref.watch(announcementsProvider);
    cards.add(_DashboardCard(
      title: 'Announcements',
      subtitle: 'Broadcasts to branch app',
      count: announcements.maybeWhen(
          data: (a) => '${a.length}', orElse: () => '…'),
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
      count: prayerRequests.maybeWhen(
          data: (p) => '${p.length}', orElse: () => '…'),
      icon: Icons.volunteer_activism,
      accentColor: AppColors.goldInk,
      onTap: () => openScreen(const PrayerScreen()),
    ));

    return cards;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the link. Please try again.')),
      );
    }
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
