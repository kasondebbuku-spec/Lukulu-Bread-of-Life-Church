import 'package:flutter/material.dart';

class GivingScreen extends StatelessWidget {
  const GivingScreen({super.key});

  final List<Map<String, String>> mockGiving = const [
    {'category': 'Tithes', 'amount': '2,450 ZMW', 'date': 'May 19'},
    {'category': 'Offerings', 'amount': '850 ZMW', 'date': 'May 19'},
    {'category': 'Building Fund', 'amount': '500 ZMW', 'date': 'May 12'},
    {'category': 'Missions', 'amount': '300 ZMW', 'date': 'May 5'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giving & Tithes')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Total This Month',
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('4,100 ZMW',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.green)),
                  const SizedBox(height: 8),
                  const Text('+12% vs last month',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent Transactions',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: mockGiving.length,
              itemBuilder: (context, index) {
                final gift = mockGiving[index];
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(gift['category']!),
                  subtitle: Text(gift['date']!),
                  trailing: Text(gift['amount']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
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
