import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final DateTime date;
  final int count;
  final int newVisitors;

  /// Nullable — only present on records entered with a breakdown. Older
  /// records (or ones entered without a breakdown) just have `count`.
  final int? men;
  final int? women;
  final int? children;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.count,
    required this.newVisitors,
    this.men,
    this.women,
    this.children,
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
      men: (data['men'] as num?)?.toInt(),
      women: (data['women'] as num?)?.toInt(),
      children: (data['children'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'count': count,
        'newVisitors': newVisitors,
        'createdAt': FieldValue.serverTimestamp(),
        if (men != null) 'men': men,
        if (women != null) 'women': women,
        if (children != null) 'children': children,
      };
}
