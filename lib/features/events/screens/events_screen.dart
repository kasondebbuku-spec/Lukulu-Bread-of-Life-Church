import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  final List<Map<String, String>> mockEvents = const [
    {
      'title': 'Sunday Service',
      'date': 'May 26, 09:00',
      'location': 'Main Sanctuary',
      'speaker': 'Pastor John'
    },
    {
      'title': 'Youth Night',
      'date': 'May 24, 18:00',
      'location': 'Fellowship Hall',
      'speaker': 'Bro. Peter'
    },
    {
      'title': 'Prayer Meeting',
      'date': 'May 22, 17:30',
      'location': 'Online & Church',
      'speaker': 'All Members'
    },
    {
      'title': 'Choir Rehearsal',
      'date': 'May 21, 15:00',
      'location': 'Music Room',
      'speaker': 'Sis. Grace'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Events')),
      body: ListView.builder(
        itemCount: mockEvents.length,
        itemBuilder: (context, index) {
          final event = mockEvents[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.event, size: 32),
              title: Text(event['title']!),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['date']!),
                  Text('${event['location']} • ${event['speaker']}'),
                ],
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
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
