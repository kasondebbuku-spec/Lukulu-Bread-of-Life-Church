import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final String createdBy;
  final String targetAudience;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.targetAudience,
    this.createdAt,
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? 'No title',
      content: data['content'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? 'unknown',
      targetAudience: data['targetAudience'] as String? ?? 'all',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'createdBy': createdBy,
        'targetAudience': targetAudience,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
