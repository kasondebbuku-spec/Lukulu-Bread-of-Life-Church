import 'package:flutter/material.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  final List<Map<String, String>> mockMembers = const [
    {'name': 'John Banda', 'role': 'Elder', 'phone': '+260 97X XXX XXX'},
    {'name': 'Mary Phiri', 'role': 'Deaconess', 'phone': '+260 96X XXX XXX'},
    {
      'name': 'Peter Mwale',
      'role': 'Youth Leader',
      'phone': '+260 95X XXX XXX'
    },
    {'name': 'Grace Zulu', 'role': 'Worship Team', 'phone': '+260 97X XXX XXX'},
    {'name': 'David Chisanga', 'role': 'Usher', 'phone': '+260 96X XXX XXX'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members Directory')),
      body: ListView.builder(
        itemCount: mockMembers.length,
        itemBuilder: (context, index) {
          final member = mockMembers[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(member['name']!), // ✅ fixed: was 'title', now 'name'
              subtitle: Text('${member['role']} • ${member['phone']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: navigate to member details
              },
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
