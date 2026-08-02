import 'package:flutter/material.dart';

import 'nav_destination.dart';

/// Simple overflow list for destinations that don't fit in the bottom nav bar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.destinations});

  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        itemCount: destinations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return ListTile(
            leading: Icon(destination.icon),
            title: Text(destination.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination.builder()),
            ),
          );
        },
      ),
    );
  }
}
