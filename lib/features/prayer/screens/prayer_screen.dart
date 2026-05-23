import 'package:flutter/material.dart';

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  final List<Map<String, String>> mockPrayers = const [
    {
      'name': 'Sister Esther',
      'request': 'Healing for her mother',
      'date': 'Today'
    },
    {
      'name': 'Brother James',
      'request': 'Job interview this Friday',
      'date': 'Yesterday'
    },
    {
      'name': 'Family of late Mr. Banda',
      'request': 'Comfort and strength',
      'date': '2 days ago'
    },
    {
      'name': 'Youth Group',
      'request': 'Successful outreach event',
      'date': '3 days ago'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Request Wall')),
      body: ListView.builder(
        itemCount: mockPrayers.length,
        itemBuilder: (context, index) {
          final prayer = mockPrayers[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.volunteer_activism)),
              title: Text(prayer['name']!),
              subtitle: Text('${prayer['request']} • ${prayer['date']}'),
              trailing: const Icon(Icons.message_outlined),
              isThreeLine: true,
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
