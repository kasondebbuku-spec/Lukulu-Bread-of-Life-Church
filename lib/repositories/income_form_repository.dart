import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_record.dart';
import '../models/giving_record.dart';
import '../models/sunday_income_form.dart';
import 'attendance_repository.dart';
import 'giving_repository.dart';

class IncomeFormRepository {
  IncomeFormRepository(this._firestore, this._givingRepo, this._attendanceRepo);

  final FirebaseFirestore _firestore;
  final GivingRepository _givingRepo;
  final AttendanceRepository _attendanceRepo;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('income_forms');

  Stream<List<SundayIncomeForm>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SundayIncomeForm.fromDoc).toList());

  Future<String> add(SundayIncomeForm form) async {
    final ref = await _col.add(form.toMap());
    return ref.id;
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Saves the form, then cascades: one GivingRecord per non-empty category
  /// block (tagged with its own denomination breakdown) and one
  /// AttendanceRecord for the same date — so filling in this form once
  /// populates Giving, Attendance, and the Weekly Statement automatically.
  ///
  /// Note: this is a sequence of individual writes, not a single atomic
  /// batch/transaction — consistent with how every other write in this app
  /// works. If it's interrupted partway, the paper form remains the source
  /// of truth to re-enter from.
  Future<String> saveAndCascade(
    SundayIncomeForm form,
    Map<String, double> valuesByKey,
  ) async {
    final formId = await add(form);

    for (final entry in form.categoryBlocks.entries) {
      final amount = entry.value.amount(valuesByKey);
      if (amount <= 0) continue;
      await _givingRepo.add(GivingRecord(
        id: '',
        memberName: '${entry.key.label} (${form.service.name} service)',
        amount: amount,
        date: form.date,
        category: entry.key,
        denominationBreakdown: entry.value.denominationBreakdown,
      ));
    }

    await _attendanceRepo.add(AttendanceRecord(
      id: '',
      date: form.date,
      count: form.attendanceTotal,
      newVisitors: 0,
      men: form.men,
      women: form.women,
      children: form.children,
    ));

    return formId;
  }
}
