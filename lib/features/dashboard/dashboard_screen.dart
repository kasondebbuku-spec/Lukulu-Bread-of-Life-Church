import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../members/screens/members_screen.dart';
import '../prayer/screens/prayer_screen.dart';
import '../attendance/screens/attendance_screen.dart';
import '../giving/screens/giving_screen.dart';
import '../events/screens/events_screen.dart';
import '../announcements/screens/announcements_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userRole = 'member';
  bool isLoading = true;
  String userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      });
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          userRole = doc['role'] ?? 'member';
          isLoading = false;
        });
        debugPrint("✅ Role loaded: $userRole");
      } else {
        debugPrint("⚠️ No role document found for user ${user.uid}");
        setState(() => isLoading = false);
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    final allItems = [
      {
        'title': 'Members Directory',
        'subtitle': 'Manage branch database',
        'count': '150+',
        'icon': Icons.people,
        'isPrimaryColor': true,
        'destination': const MembersScreen(),
        'roles': ['admin', 'secretariat'],
      },
      {
        'title': 'Attendance Tracker',
        'subtitle': 'Service check-ins & data',
        'count': 'Active',
        'icon': Icons.how_to_reg,
        'isPrimaryColor': true,
        'destination': const AttendanceScreen(),
        'roles': ['admin', 'secretariat', 'pastor'],
      },
      {
        'title': 'Giving & Tithes',
        'subtitle': 'Financial records overview',
        'count': 'Secure',
        'icon': Icons.account_balance_wallet,
        'isPrimaryColor': false,
        'destination': const GivingScreen(),
        'roles': ['admin', 'secretariat'],
      },
      {
        'title': 'Upcoming Events',
        'subtitle': 'Services & church calendar',
        'count': '3 Appointed',
        'icon': Icons.event,
        'isPrimaryColor': true,
        'destination': const EventsScreen(),
        'roles': ['admin', 'secretariat', 'pastor', 'member'],
      },
      {
        'title': 'Announcements',
        'subtitle': 'Broadcasts to branch app',
        'count': 'Push Live',
        'icon': Icons.campaign,
        'isPrimaryColor': true,
        'destination': const AnnouncementsScreen(),
        'roles': ['admin', 'secretariat', 'pastor', 'member'],
      },
      {
        'title': 'Prayer Request Wall',
        'subtitle': 'Review intercessory wall',
        'count': '5 New',
        'icon': Icons.volunteer_activism,
        'isPrimaryColor': false,
        'destination': const PrayerScreen(),
        'roles': ['admin', 'secretariat', 'pastor', 'member'],
      },
    ];

    // Filter by role with null safety
    return allItems.where((item) {
      final roles = item['roles'] as List<String>?;
      return roles != null && roles.contains(userRole);
    }).toList();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dashboardItems = _getFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bread of Life Lukulu Branch'),
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await _logout();
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
                    Text('Role: ${userRole.toUpperCase()}',
                        style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 4),
            Text(
              'Role: ${userRole.toUpperCase()}',
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

                // Replace deprecated withOpacity with withValues()
                final backgroundColor = cardColor.withValues(alpha: 0.1);

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => item['destination'] as Widget),
                    );
                  },
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
                                  color: backgroundColor,
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
