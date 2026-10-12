import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../core/utils/currency_format.dart';
import '../core/utils/date_format.dart';
import '../models/attendance_record.dart';
import '../models/audit_entry.dart';
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

  CollectionReference<Map<String, dynamic>> get _giving =>
      _firestore.collection(FirestoreCollections.giving);
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _firestore.collection(FirestoreCollections.attendance);

  static String givingRecordId(String formId, GivingCategory category) =>
      '${formId}_${category.name}';
  static String attendanceRecordId(String formId) => '${formId}_attendance';

  CollectionReference<Map<String, dynamic>> get _auditLog =>
      _firestore.collection(FirestoreCollections.auditLog);

  static String _summary(SundayIncomeForm form) =>
      '${formatDate(form.date)} - ${form.service.label} service';

  /// Adds an activity-log entry to [batch], so the change and its record are
  /// committed together or not at all.
  void _writeAudit(
    WriteBatch batch, {
    required AuditAction action,
    required String formId,
    required SundayIncomeForm form,
    required String detail,
    required AuditActor actor,
  }) {
    batch.set(
      _auditLog.doc(),
      AuditEntry.newEntry(
        action: action,
        entity: 'income_form',
        entityId: formId,
        summary: _summary(form),
        detail: detail,
        actor: actor,
      ),
    );
  }

  /// Adds the writes for the records derived from [form] to [batch]: one
  /// [GivingRecord] per non-empty category (empty ones are removed, in case an
  /// edit cleared them) and one [AttendanceRecord]. Ids are keyed on [formId]
  /// so a later edit or delete addresses exactly these documents.
  void _writeCascade(
    WriteBatch batch,
    String formId,
    SundayIncomeForm form,
    Map<String, double> valuesByKey,
  ) {
    for (final entry in form.categoryBlocks.entries) {
      final ref = _giving.doc(givingRecordId(formId, entry.key));
      final amount = entry.value.amount(valuesByKey);
      if (amount <= 0) {
        batch.delete(ref);
        continue;
      }
      batch.set(
        ref,
        GivingRecord(
          id: '',
          memberName: '${entry.key.label} (${form.service.name} service)',
          amount: amount,
          date: form.date,
          category: entry.key,
          denominationBreakdown: entry.value.denominationBreakdown,
        ).toMap()
          ..['incomeFormId'] = formId,
      );
    }

    batch.set(
      _attendance.doc(attendanceRecordId(formId)),
      AttendanceRecord(
        id: '',
        date: form.date,
        count: form.attendanceTotal,
        newVisitors: 0,
        men: form.men,
        women: form.women,
        children: form.children,
      ).toMap()
        ..['incomeFormId'] = formId,
    );
  }

  /// Saves the form, then cascades into giving and attendance records -- all in
  /// a single atomic Firestore batch so partial writes cannot occur.
  Future<String> saveAndCascade(
    SundayIncomeForm form,
    Map<String, double> valuesByKey, {
    required AuditActor actor,
  }) async {
    final batch = _firestore.batch();
    final formRef = col.doc();
    batch.set(formRef, form.toMap());
    _writeCascade(batch, formRef.id, form, valuesByKey);
    _writeAudit(
      batch,
      action: AuditAction.create,
      formId: formRef.id,
      form: form,
      detail: 'Total ${formatZmw(form.grandTotal(valuesByKey))}',
      actor: actor,
    );
    await batch.commit();
    return formRef.id;
  }

  /// Rewrites an existing form and the records derived from it atomically.
  /// Only valid for forms whose records are keyed by id ([SundayIncomeForm.canEdit]).
  Future<void> updateAndCascade(
    SundayIncomeForm form,
    Map<String, double> valuesByKey, {
    required SundayIncomeForm previous,
    required AuditActor actor,
  }) async {
    if (!form.canEdit) {
      throw StateError('This form predates editing and cannot be changed.');
    }
    final batch = _firestore.batch();
    batch.set(
      col.doc(form.id),
      form.toMap()
        ..remove('createdAt')
        ..['updatedAt'] = FieldValue.serverTimestamp(),
      SetOptions(merge: true),
    );
    _writeCascade(batch, form.id, form, valuesByKey);
    final before = previous.grandTotal(valuesByKey);
    final after = form.grandTotal(valuesByKey);
    _writeAudit(
      batch,
      action: AuditAction.update,
      formId: form.id,
      form: form,
      detail: before == after
          ? 'Total unchanged at ${formatZmw(after)}'
          : 'Total ${formatZmw(before)} -> ${formatZmw(after)}',
      actor: actor,
    );
    await batch.commit();
  }

  /// Deletes the form together with the giving and attendance records it created.
  Future<void> deleteAndCascade(
    SundayIncomeForm form,
    Map<String, double> valuesByKey, {
    required AuditActor actor,
  }) async {
    if (!form.canEdit) {
      throw StateError('This form predates editing and cannot be deleted here.');
    }
    final batch = _firestore.batch();
    for (final category in GivingCategory.values) {
      batch.delete(_giving.doc(givingRecordId(form.id, category)));
    }
    batch.delete(_attendance.doc(attendanceRecordId(form.id)));
    batch.delete(col.doc(form.id));
    _writeAudit(
      batch,
      action: AuditAction.delete,
      formId: form.id,
      form: form,
      detail: 'Total was ${formatZmw(form.grandTotal(valuesByKey))}',
      actor: actor,
    );
    await batch.commit();
  }
}
