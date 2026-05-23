import 'package:flutter/material.dart';
import '../members/screens/members_screen.dart';
import '../prayer/screens/prayer_screen.dart';
// 🟢 Add these imports for the new screens
import '../attendance/screens/attendance_screen.dart';
import '../giving/screens/giving_screen.dart';
import '../events/screens/events_screen.dart';
import '../announcements/screens/announcements_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Members Directory',
        'subtitle': 'Manage branch database',
        'count': '150+',
        'icon': Icons.people,
        'isPrimaryColor': true,
        'destination': MembersScreen(),
      },
      {
        'title': 'Attendance Tracker',
        'subtitle': 'Service check-ins & data',
        'count': 'Active',
        'icon': Icons.how_to_reg,
        'isPrimaryColor': true,
        'destination': const AttendanceScreen(), // 🟢 Now clickable
      },
      {
        'title': 'Giving & Tithes',
        'subtitle': 'Financial records overview',
        'count': 'Secure',
        'icon': Icons.account_balance_wallet,
        'isPrimaryColor': false,
        'destination': const GivingScreen(),
      },
      {
        'title': 'Upcoming Events',
        'subtitle': 'Services & church calendar',
        'count': '3 Appointed',
        'icon': Icons.event,
        'isPrimaryColor': true,
        'destination': const EventsScreen(),
      },
      {
        'title': 'Announcements',
        'subtitle': 'Broadcasts to branch app',
        'count': 'Push Live',
        'icon': Icons.campaign,
        'isPrimaryColor': true,
        'destination': const AnnouncementsScreen(),
      },
      {
        'title': 'Prayer Request Wall',
        'subtitle': 'Review intercessory wall',
        'count': '5 New',
        'icon': Icons.volunteer_activism,
        'isPrimaryColor': false,
        'destination': PrayerScreen(),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Bread of Life Lukulu Branch Church Management System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Admin',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Bread of Life Church — Lukulu Branch Management Portal',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dashboardItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                final item = dashboardItems[index];
                final cardColor = item['isPrimaryColor'] as bool
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary;

                return InkWell(
                  onTap: item['destination'] != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  item['destination'] as Widget,
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(item['icon'] as IconData,
                                  color: cardColor, size: 32),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cardColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['count'] as String,
                                  style: TextStyle(
                                    color: cardColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['subtitle'] as String,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
