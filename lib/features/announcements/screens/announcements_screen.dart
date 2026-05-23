import 'package:flutter/material.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  final List<Map<String, String>> mockAnnouncements = const [
    {
      'title': 'Leadership Training',
      'date': 'May 25',
      'description': 'All department heads attend at 14:00.'
    },
    {
      'title': 'Outreach Program',
      'date': 'June 1',
      'description': 'Visit to local orphanage – volunteers needed.'
    },
    {
      'title': 'New Choir Uniforms',
      'date': 'May 30',
      'description': 'Final fitting after Sunday service.'
    },
    {
      'title': 'Branch Conference',
      'date': 'June 8-9',
      'description': 'Theme: "Rise and Build". Register online.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: ListView.builder(
        itemCount: mockAnnouncements.length,
        itemBuilder: (context, index) {
          final ann = mockAnnouncements[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(ann['title']!),
              subtitle: Text('${ann['date']}\n${ann['description']}'),
              isThreeLine: true,
              trailing: const Icon(Icons.more_vert),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
