import 'package:cloud_firestore/cloud_firestore.dart';

class GivingRecord {
  final String id;
  final String memberName;
  final double amount;
  final String currency;
  final DateTime date;

  const GivingRecord({
    required this.id,
    required this.memberName,
    required this.amount,
    this.currency = 'ZMW',
    required this.date,
  });

  factory GivingRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawAmount = data['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return GivingRecord(
      id: doc.id,
      memberName: data['memberName'] as String? ?? 'Unknown',
      amount: amount,
      currency: data['currency'] as String? ?? 'ZMW',
      date: date,
    );
  }

  Map<String, dynamic> toMap() => {
        'memberName': memberName,
        'amount': amount,
        'currency': currency,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
