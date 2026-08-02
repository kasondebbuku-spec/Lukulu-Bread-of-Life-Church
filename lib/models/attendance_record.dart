import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final DateTime date;
  final int count;
  final int newVisitors;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.count,
    required this.newVisitors,
  });

  factory AttendanceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return AttendanceRecord(
      id: doc.id,
      date: date,
      count: (data['count'] as num?)?.toInt() ?? 0,
      newVisitors: (data['newVisitors'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'count': count,
        'newVisitors': newVisitors,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
