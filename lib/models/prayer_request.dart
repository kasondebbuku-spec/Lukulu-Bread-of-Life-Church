import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequest {
  final String id;
  final String userId;
  final String userName;
  final String request;
  final String status;
  final DateTime? createdAt;

  const PrayerRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.request,
    required this.status,
    this.createdAt,
  });

  bool get isAnswered => status == 'answered';

  factory PrayerRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return PrayerRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Anonymous',
      request: data['request'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'request': request,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
