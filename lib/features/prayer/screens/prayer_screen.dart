import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final TextEditingController _requestController = TextEditingController();
  String userRole = 'member';
  String userId = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      _loadUserRole();
    }
  }

  Future<void> _loadUserRole() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists && mounted) {
      setState(() {
        userRole = doc['role'] ?? 'member';
      });
    }
  }

  bool get canSeeAll => ['admin', 'secretariat', 'pastor'].contains(userRole);

  Future<void> _addPrayerRequest() async {
    final content = _requestController.text.trim();
    if (content.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('prayer_requests').add({
      'userId': userId,
      'userName': user?.displayName ?? user?.email,
      'request': content,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    if (!mounted) return;
    _requestController.clear();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prayer Request'),
        content: TextField(
          controller: _requestController,
          decoration: const InputDecoration(
              labelText: 'What would you like prayer for?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _addPrayerRequest, child: const Text('Submit')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('prayer_requests');
    if (!canSeeAll) {
      query = query.where('userId', isEqualTo: userId);
    }
    query = query.orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(canSeeAll
                  ? 'No prayer requests yet.'
                  : 'You have not submitted any prayer requests.'),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.volunteer_activism,
                      color: Colors.purple),
                  title: Text(data['request'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canSeeAll)
                        Text('From: ${data['userName'] ?? 'Anonymous'}'),
                      Text(
                          'Submitted: ${(data['createdAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'recent'}'),
                    ],
                  ),
                  isThreeLine: canSeeAll,
                  trailing: canSeeAll
                      ? PopupMenuButton(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await docs[index].reference.delete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
