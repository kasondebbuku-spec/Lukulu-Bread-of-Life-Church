import 'package:cloud_firestore/cloud_firestore.dart';

class ChurchEvent {
  final String id;
  final String title;
  final DateTime date;
  final String location;

  const ChurchEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
  });

  factory ChurchEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return ChurchEvent(
      id: doc.id,
      title: data['title'] as String? ?? 'No title',
      date: date,
      location: data['location'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
