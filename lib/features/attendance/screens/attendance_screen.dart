// lib/features/attendance/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String userRole = 'member';
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _newVisitorsController = TextEditingController();

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

  bool get canEdit => ['admin', 'secretariat'].contains(userRole);

  Future<void> _addAttendance() async {
    final date = _dateController.text.trim();
    final count = int.tryParse(_countController.text.trim());
    final newVisitors = int.tryParse(_newVisitorsController.text.trim());
    if (date.isEmpty || count == null || newVisitors == null) return;

    await FirebaseFirestore.instance.collection('attendance').add({
      'date': date,
      'count': count,
      'newVisitors': newVisitors,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _dateController.clear();
    _countController.clear();
    _newVisitorsController.clear();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Attendance Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                    labelText: 'Date (e.g., Sunday, May 25)')),
            TextField(
                controller: _countController,
                decoration:
                    const InputDecoration(labelText: 'Total Attendance'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _newVisitorsController,
                decoration: const InputDecoration(labelText: 'New Visitors'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: _addAttendance, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _deleteAttendance(String docId) async {
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Tracker')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No attendance records yet.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(data['date'] ?? 'No date'),
                  subtitle: Text(
                      'Attended: ${data['count']}  •  New: ${data['newVisitors']}'),
                  trailing: canEdit
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAttendance(docId))
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _showAddDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}
