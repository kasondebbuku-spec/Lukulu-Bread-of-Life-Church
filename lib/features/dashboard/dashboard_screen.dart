import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/social_links.dart';
import '../../core/providers/firebase_providers.dart';
import '../../core/providers/user_role_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../core/widgets/role_badge.dart';
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
          orElse: () => UserAccess.member,
        );
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

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
                    RoleBadge(role: role),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.blueDark
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.church_outlined,
                      color: AppColors.secondaryLight, size: 36),
                  const SizedBox(height: 20),
                  const Text('BREAD OF LIFE • LUKULU',
                      style: TextStyle(
                        color: AppColors.secondaryLight,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      )),
                  const SizedBox(height: 12),
                  Text('Welcome, $userName',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Growing in faith. Serving together.',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  RoleBadge(role: role),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Your church community',
                style: Theme.of(context).textTheme.headlineMedium),
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
    );
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

    final events = ref.watch(upcomingEventsProvider);
    cards.add(_DashboardCard(
      title: 'Upcoming Events',
      subtitle: 'Services & church calendar',
      count: events.when(
        data: (e) => '${e.length}',
        loading: () => 'Loading…',
        error: (error, stack) => 'Unavailable',
      ),
      icon: Icons.event,
      accentColor: AppColors.blue,
      onTap: () => openScreen(const EventsScreen()),
    ));

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

    cards.add(_DashboardCard(
      title: 'Join WhatsApp Group',
      subtitle: 'Chat with the branch community',
      count: 'Open',
      icon: Icons.chat_bubble_outline,
      accentColor: AppColors.blue,
      onTap: () => _openWhatsAppGroup(context),
    ));

    return cards;
  }

  Future<void> _openWhatsAppGroup(BuildContext context) async {
    final uri = Uri.parse(SocialLinks.whatsAppGroup);
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
            content: Text('Could not open WhatsApp. Is it installed?')),
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
