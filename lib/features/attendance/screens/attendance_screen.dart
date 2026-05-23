import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  final List<Map<String, String>> mockAttendance = const [
    {'date': 'Sunday, May 19', 'count': '87', 'newVisitors': '5'},
    {'date': 'Wednesday, May 15', 'count': '42', 'newVisitors': '2'},
    {'date': 'Sunday, May 12', 'count': '92', 'newVisitors': '7'},
    {'date': 'Wednesday, May 8', 'count': '38', 'newVisitors': '1'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Tracker')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total This Month',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('259',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                Column(
                  children: [
                    const Text('Avg. Weekly', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('86',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent Services',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: mockAttendance.length,
              itemBuilder: (context, index) {
                final record = mockAttendance[index];
                return ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(record['date']!),
                  subtitle: Text(
                      'Attended: ${record['count']}  •  New: ${record['newVisitors']}'),
                  trailing: const Icon(Icons.trending_up),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
