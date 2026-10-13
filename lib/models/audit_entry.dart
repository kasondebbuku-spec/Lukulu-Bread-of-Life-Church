import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction { create, update, delete }

extension AuditActionX on AuditAction {
  String get label => switch (this) {
        AuditAction.create => 'created',
        AuditAction.update => 'edited',
        AuditAction.delete => 'deleted',
      };
}

/// Who is performing an action, recorded alongside it.
class AuditActor {
  const AuditActor({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// One immutable line in the activity log: who did what to which record, when.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.summary,
    required this.detail,
    required this.userId,
    required this.userName,
    this.createdAt,
  });

  final String id;
  final AuditAction action;

  /// What kind of record, e.g. `income_form`.
  final String entity;
  final String entityId;

  /// Human-readable subject, e.g. "Oct 4, 2026 - Morning service".
  final String summary;

  /// What changed, e.g. "Total ZMW 2900.00 -> ZMW 3100.00".
  final String detail;
  final String userId;
  final String userName;
  final DateTime? createdAt;

  factory AuditEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final raw = data['createdAt'];
    return AuditEntry(
      id: doc.id,
      action: AuditAction.values.firstWhere(
        (a) => a.name == data['action'],
        orElse: () => AuditAction.update,
      ),
      entity: data['entity'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      createdAt: raw is Timestamp ? raw.toDate() : null,
    );
  }

  static Map<String, dynamic> newEntry({
    required AuditAction action,
    required String entity,
    required String entityId,
    required String summary,
    required String detail,
    required AuditActor actor,
  }) =>
      {
        'action': action.name,
        'entity': entity,
        'entityId': entityId,
        'summary': summary,
        'detail': detail,
        'userId': actor.uid,
        'userName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
