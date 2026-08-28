import 'package:cloud_firestore/cloud_firestore.dart';

import 'cheque_entry.dart';
import 'forex_entry.dart';
import 'giving_record.dart';

enum ServiceType { morning, evening }

extension ServiceTypeX on ServiceType {
  String get label => this == ServiceType.morning ? 'Morning' : 'Evening';
}

/// One category's 10-row denomination count. Amount is derived from the
/// breakdown, never stored redundantly — so the two numbers can never
/// disagree, matching how the paper form's own cells are formulas.
class CategoryBlock {
  const CategoryBlock({required this.denominationBreakdown});

  final Map<String, int> denominationBreakdown;

  double amount(Map<String, double> valuesByKey) => denominationBreakdown.entries
      .fold(0.0, (total, e) => total + e.value * (valuesByKey[e.key] ?? 0));

  factory CategoryBlock.fromMap(Map<String, dynamic> map) => CategoryBlock(
        denominationBreakdown: Map<String, int>.from(
          (map['denominationBreakdown'] as Map? ?? {})
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        ),
      );

  Map<String, dynamic> toMap() => {'denominationBreakdown': denominationBreakdown};
}

/// The full weekly "Income Analysis Breakdown (Form 2)" — one document per
/// service. Saving one of these cascades into GivingRecords (per category)
/// and an AttendanceRecord, so the rest of the app never needs re-entry.
class SundayIncomeForm {
  const SundayIncomeForm({
    required this.id,
    required this.date,
    required this.service,
    required this.categoryBlocks,
    required this.forexEntries,
    required this.chequeEntries,
    required this.men,
    required this.women,
    required this.children,
    required this.preparedBy,
    required this.checkedBy,
    required this.collectedBy,
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final ServiceType service;

  /// One entry per GivingCategory value.
  final Map<GivingCategory, CategoryBlock> categoryBlocks;
  final List<ForexEntry> forexEntries;
  final List<ChequeEntry> chequeEntries;
  final int men;
  final int women;
  final int children;
  final String preparedBy;
  final String checkedBy;
  final String collectedBy;
  final DateTime? createdAt;

  int get attendanceTotal => men + women + children;

  double categoryAmount(GivingCategory category, Map<String, double> valuesByKey) =>
      categoryBlocks[category]?.amount(valuesByKey) ?? 0;

  /// Sum of all 5 categories' counted cash — the "Overall" cash total.
  double overallCashTotal(Map<String, double> valuesByKey) =>
      categoryBlocks.values.fold(0.0, (total, b) => total + b.amount(valuesByKey));

  double get totalForexKwacha =>
      forexEntries.fold(0.0, (total, f) => total + f.kwachaValue);

  double get totalCheques => chequeEntries.fold(0.0, (total, c) => total + c.amount);

  /// Merged denomination counts across all 5 categories — the "Overall" block.
  Map<String, int> overallDenominationCounts() {
    final merged = <String, int>{};
    for (final block in categoryBlocks.values) {
      block.denominationBreakdown.forEach((key, n) {
        merged[key] = (merged[key] ?? 0) + n;
      });
    }
    return merged;
  }

  double grandTotal(Map<String, double> valuesByKey) =>
      overallCashTotal(valuesByKey) + totalForexKwacha + totalCheques;

  double twentyPercentOfTithe(Map<String, double> valuesByKey) =>
      categoryAmount(GivingCategory.tithe, valuesByKey) * 0.20;

  /// Returns a copy with a different id — used once the server assigns one
  /// on save, so the caller doesn't have to rebuild the whole object by hand.
  SundayIncomeForm copyWithId(String newId) => SundayIncomeForm(
        id: newId,
        date: date,
        service: service,
        categoryBlocks: categoryBlocks,
        forexEntries: forexEntries,
        chequeEntries: chequeEntries,
        men: men,
        women: women,
        children: children,
        preparedBy: preparedBy,
        checkedBy: checkedBy,
        collectedBy: collectedBy,
        createdAt: createdAt,
      );

  factory SundayIncomeForm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawDate = data['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final rawCreated = data['createdAt'];
    final createdAt = rawCreated is Timestamp ? rawCreated.toDate() : null;

    final rawBlocks = data['categoryBlocks'] as Map? ?? {};
    final blocks = <GivingCategory, CategoryBlock>{};
    for (final c in GivingCategory.values) {
      final raw = rawBlocks[c.name];
      blocks[c] = raw is Map
          ? CategoryBlock.fromMap(Map<String, dynamic>.from(raw))
          : const CategoryBlock(denominationBreakdown: {});
    }

    return SundayIncomeForm(
      id: doc.id,
      date: date,
      service:
          (data['service'] as String?) == 'evening' ? ServiceType.evening : ServiceType.morning,
      categoryBlocks: blocks,
      forexEntries: ((data['forexEntries'] as List?) ?? [])
          .map((e) => ForexEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      chequeEntries: ((data['chequeEntries'] as List?) ?? [])
          .map((e) => ChequeEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      men: (data['men'] as num?)?.toInt() ?? 0,
      women: (data['women'] as num?)?.toInt() ?? 0,
      children: (data['children'] as num?)?.toInt() ?? 0,
      preparedBy: data['preparedBy'] as String? ?? '',
      checkedBy: data['checkedBy'] as String? ?? '',
      collectedBy: data['collectedBy'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'service': service.name,
        'categoryBlocks': {
          for (final e in categoryBlocks.entries) e.key.name: e.value.toMap(),
        },
        'forexEntries': forexEntries.map((f) => f.toMap()).toList(),
        'chequeEntries': chequeEntries.map((c) => c.toMap()).toList(),
        'men': men,
        'women': women,
        'children': children,
        'preparedBy': preparedBy,
        'checkedBy': checkedBy,
        'collectedBy': collectedBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
