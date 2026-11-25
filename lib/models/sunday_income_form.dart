import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cheque_entry.dart';
import 'expense_entry.dart';
import 'forex_entry.dart';
import 'giving_record.dart';

enum ServiceType { morning, evening }

/// The tithe of tithes is this share of the total tithe (20%). It is worked out
/// from the tithe count, never typed in, and it is not an expense. This is the
/// only place the rate is written: change it here and the labels in the screens,
/// PDFs and CSV header follow. Totals are never stored, so every form already
/// saved is recalculated at the new rate too.
const titheOfTithesRate = 0.20;

/// The rate as it reads in a label, e.g. `20`.
final titheOfTithesPercent = (titheOfTithesRate * 100).round();

extension ServiceTypeX on ServiceType {
  String get label => this == ServiceType.morning ? 'Morning' : 'Evening';
}

/// One category's denomination count. Amount is derived from the
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
    this.expenseEntries = const [],
    this.enteredBy = '',
    this.enteredByUid = '',
    this.preparedBySignature,
    this.checkedBySignature,
    this.collectedBySignature,
    this.recordsKeyedById = true,
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

  /// The itemised expenses (a description and an amount each). Their total is
  /// taken off the grand total; there is no separate cash count for them.
  final List<ExpenseEntry> expenseEntries;

  /// Who typed this form into the app (their account name and id), recorded
  /// when it is first saved so leaders can see who entered what. Empty on forms
  /// saved before this was recorded; [preparedBy] is the fallback name there.
  final String enteredBy;
  final String enteredByUid;

  /// The name to show for "entered by": the person who saved it, or the
  /// prepared-by name on older forms.
  String get enteredByLabel => enteredBy.isNotEmpty ? enteredBy : preparedBy;

  /// Drawn signatures (PNG bytes), stored base64 in the document. Optional --
  /// a form can still be saved with only the typed names.
  final Uint8List? preparedBySignature;
  final Uint8List? checkedBySignature;
  final Uint8List? collectedBySignature;

  /// True when this form's giving/attendance records use predictable ids
  /// (`<formId>_<category>` / `<formId>_attendance`), which is what lets an
  /// edit or delete update exactly those records. Forms saved before this was
  /// introduced have random ids and stay read-only.
  final bool recordsKeyedById;
  final DateTime? createdAt;

  bool get canEdit => recordsKeyedById;

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

  /// [titheOfTithesRate] of the total tithe. Shown as its own line; never an expense entry.
  double titheOfTithes(Map<String, double> valuesByKey) =>
      categoryAmount(GivingCategory.tithe, valuesByKey) * titheOfTithesRate;

  /// What goes into the NATSAVE bank account: everything received on Sunday
  /// ([grandTotal]) less the tithe of tithes and less the expenses. It is the
  /// rest, so it is calculated and never typed in.
  double natsaveDeposit(Map<String, double> valuesByKey) =>
      grandTotal(valuesByKey) - titheOfTithes(valuesByKey) - totalExpenses;

  double get totalExpenses =>
      expenseEntries.fold(0.0, (total, e) => total + e.amount);

  /// The grand total less the expenses: what is left once they are deducted.
  /// The tithe of tithes is not deducted here; it stays a separate line.
  double netAmount(Map<String, double> valuesByKey) =>
      grandTotal(valuesByKey) - totalExpenses;

  /// Mirrors the paper form's own "Total collection" line: the tithe of tithes
  /// plus the Natsave deposit. Since the Natsave deposit is the rest, this is
  /// the same as the [netAmount].
  double totalCollection(Map<String, double> valuesByKey) =>
      titheOfTithes(valuesByKey) + natsaveDeposit(valuesByKey);

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
        expenseEntries: expenseEntries,
        enteredBy: enteredBy,
        enteredByUid: enteredByUid,
        preparedBySignature: preparedBySignature,
        checkedBySignature: checkedBySignature,
        collectedBySignature: collectedBySignature,
        recordsKeyedById: recordsKeyedById,
        createdAt: createdAt,
      );

  static Uint8List? _decodeSignature(Object? raw) =>
      raw is String && raw.isNotEmpty ? base64Decode(raw) : null;

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
      expenseEntries: ((data['expenseEntries'] as List?) ?? [])
          .map((e) => ExpenseEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      enteredBy: data['enteredBy'] as String? ?? '',
      enteredByUid: data['enteredByUid'] as String? ?? '',
      preparedBySignature: _decodeSignature(data['preparedBySignature']),
      checkedBySignature: _decodeSignature(data['checkedBySignature']),
      collectedBySignature: _decodeSignature(data['collectedBySignature']),
      recordsKeyedById: data['recordsKeyedById'] == true,
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
        'expenseEntries': expenseEntries.map((e) => e.toMap()).toList(),
        if (enteredBy.isNotEmpty) 'enteredBy': enteredBy,
        if (enteredByUid.isNotEmpty) 'enteredByUid': enteredByUid,
        if (preparedBySignature != null)
          'preparedBySignature': base64Encode(preparedBySignature!),
        if (checkedBySignature != null)
          'checkedBySignature': base64Encode(checkedBySignature!),
        if (collectedBySignature != null)
          'collectedBySignature': base64Encode(collectedBySignature!),
        'recordsKeyedById': true,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
