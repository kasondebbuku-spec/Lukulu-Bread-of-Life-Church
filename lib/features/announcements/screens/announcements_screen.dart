import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String userRole = 'member';
  String _selectedAudience = 'all'; // 'all' or 'leaders'

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          userRole = doc['role'] ?? 'member';
        });
      }
    }
  }

  bool get canWrite => ['admin', 'secretariat', 'pastor'].contains(userRole);

  Future<void> _addAnnouncement() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('announcements').add({
      'title': title,
      'content': content,
      'createdBy': user?.displayName ?? user?.email,
      'createdAt': FieldValue.serverTimestamp(),
      'targetAudience': _selectedAudience, // 👈 new field
    });
    if (!mounted) return;
    _titleController.clear();
    _contentController.clear();
    _selectedAudience = 'all';
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New Announcement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: 3),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAudience,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Everyone (all members)')),
                    DropdownMenuItem(
                        value: 'leaders',
                        child:
                            Text('Leaders only (admin, secretariat, pastor)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedAudience = value!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: _addAnnouncement, child: const Text('Post')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAnnouncement(String docId) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No announcements yet.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final audience = data['targetAudience'] ?? 'all';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(data['title'] ?? 'No title'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['content'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        'Posted by ${data['createdBy'] ?? 'unknown'} • ${(data['createdAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'recent'}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (canWrite && audience == 'leaders')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Leaders only',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.orange)),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: canWrite
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAnnouncement(docId),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
