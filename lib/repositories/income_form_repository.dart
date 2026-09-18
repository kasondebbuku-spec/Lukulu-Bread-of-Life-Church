import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/attendance_record.dart';
import '../models/giving_record.dart';
import '../models/sunday_income_form.dart';

class IncomeFormRepository extends FirestoreRepository<SundayIncomeForm> {
  IncomeFormRepository(this._firestore)
      : super(_firestore, FirestoreCollections.incomeForms);

  final FirebaseFirestore _firestore;

  @override
  SundayIncomeForm fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SundayIncomeForm.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(SundayIncomeForm form) => form.toMap();

  /// Saves the form, then cascades: one [GivingRecord] per non-empty category
  /// block and one [AttendanceRecord] for the same date — all in a single
  /// atomic Firestore batch so partial writes cannot occur.
  Future<String> saveAndCascade(
    SundayIncomeForm form,
    Map<String, double> valuesByKey,
  ) async {
    final batch = _firestore.batch();
    final formRef = col.doc();
    batch.set(formRef, form.toMap());

    for (final entry in form.categoryBlocks.entries) {
      final amount = entry.value.amount(valuesByKey);
      if (amount <= 0) continue;

      final givingRef =
          _firestore.collection(FirestoreCollections.giving).doc();
      batch.set(
        givingRef,
        GivingRecord(
          id: '',
          memberName: '${entry.key.label} (${form.service.name} service)',
          amount: amount,
          date: form.date,
          category: entry.key,
          denominationBreakdown: entry.value.denominationBreakdown,
        ).toMap()
          ..['incomeFormId'] = formRef.id,
      );
    }

    final attendanceRef =
        _firestore.collection(FirestoreCollections.attendance).doc();
    batch.set(
      attendanceRef,
      AttendanceRecord(
        id: '',
        date: form.date,
        count: form.attendanceTotal,
        newVisitors: 0,
        men: form.men,
        women: form.women,
        children: form.children,
      ).toMap()
        ..['incomeFormId'] = formRef.id,
    );

    await batch.commit();
    return formRef.id;
  }
}
