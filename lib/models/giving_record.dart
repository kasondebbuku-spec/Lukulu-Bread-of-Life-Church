import 'package:cloud_firestore/cloud_firestore.dart';

enum GivingCategory { tithe, offering, seed, thanksgiving, pledge }

extension GivingCategoryX on GivingCategory {
  String get label {
    switch (this) {
      case GivingCategory.tithe:
        return 'Tithe';
      case GivingCategory.offering:
        return 'Offering';
      case GivingCategory.seed:
        return 'Seed';
      case GivingCategory.thanksgiving:
        return 'Thanksgiving';
      case GivingCategory.pledge:
        return 'Pledge';
    }
  }
}

class GivingRecord {
  final String id;
  final String memberName;
  final String? memberUserId;
  final String? recordedBy;
  final double amount;
  final String currency;
  final DateTime date;

  /// Null means legacy/uncategorized — records written before categories
  /// were introduced have no `category` field in Firestore at all.
  final GivingCategory? category;

  /// Only present for cash-counted entries (e.g. a Sunday offering tally).
  /// Denomination value (e.g. "100", "0.5") -> count.
  final Map<String, int>? denominationBreakdown;

  const GivingRecord({
    required this.id,
    required this.memberName,
    this.memberUserId,
    this.recordedBy,
    required this.amount,
    this.currency = 'ZMW',
    required this.date,
    this.category,
    this.denominationBreakdown,
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

    final rawCategory = data['category'] as String?;
    GivingCategory? category;
    for (final c in GivingCategory.values) {
      if (c.name == rawCategory) {
        category = c;
        break;
      }
    }

    final rawBreakdown = data['denominationBreakdown'];
    final denominationBreakdown = rawBreakdown is Map
        ? Map<String, int>.from(rawBreakdown
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : null;

    return GivingRecord(
      id: doc.id,
      memberName: data['memberName'] as String? ?? 'Unknown',
      memberUserId: data['memberUserId'] as String?,
      recordedBy: data['recordedBy'] as String?,
      amount: amount,
      currency: data['currency'] as String? ?? 'ZMW',
      date: date,
      category: category,
      denominationBreakdown: denominationBreakdown,
    );
  }

  Map<String, dynamic> toMap() => {
        'memberName': memberName,
        if (memberUserId != null) 'memberUserId': memberUserId,
        if (recordedBy != null) 'recordedBy': recordedBy,
        'amount': amount,
        'currency': currency,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        if (category != null) 'category': category!.name,
        if (denominationBreakdown != null)
          'denominationBreakdown': denominationBreakdown,
      };
}
