import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus { sent, reviewed }

const reportSummaryMaxLength = 4000;
const reportNotesMaxLength = 2000;
const reportMaxAttendance = 100000;

/// A report a ministry leader sends to the Pastor about their ministry.
class MinistryReport {
  const MinistryReport({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.ministryKey,
    required this.ministry,
    required this.position,
    required this.period,
    required this.summary,
    this.attendance = 0,
    this.challenges = '',
    this.needs = '',
    this.status = ReportStatus.sent,
    this.createdAt,
    this.pastorNote = '',
    this.reviewedBy = '',
    this.reviewedAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String ministryKey;
  final String ministry;

  /// The author's title there, e.g. `Leader`.
  final String position;

  /// The day (or meeting) the report is about.
  final DateTime period;
  final int attendance;
  final String summary;
  final String challenges;
  final String needs;
  final ReportStatus status;
  final DateTime? createdAt;

  /// The Pastor's reply, and who marked it reviewed and when.
  final String pastorNote;
  final String reviewedBy;
  final DateTime? reviewedAt;

  bool get isReviewed => status == ReportStatus.reviewed;

  factory MinistryReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    DateTime day(Object? v) {
      final t = v is Timestamp ? v.toDate() : DateTime.now();
      return DateTime(t.year, t.month, t.day);
    }

    final a = d['attendance'];
    return MinistryReport(
      id: doc.id,
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      ministryKey: d['ministryKey'] as String? ?? '',
      ministry: d['ministry'] as String? ?? '',
      position: d['position'] as String? ?? '',
      period: day(d['period']),
      attendance: a is num ? a.toInt() : 0,
      summary: d['summary'] as String? ?? '',
      challenges: d['challenges'] as String? ?? '',
      needs: d['needs'] as String? ?? '',
      status: d['status'] == 'reviewed' ? ReportStatus.reviewed : ReportStatus.sent,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      pastorNote: d['pastorNote'] as String? ?? '',
      reviewedBy: d['reviewedBy'] as String? ?? '',
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Written once, when the report is first sent.
  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'ministryKey': ministryKey,
        'ministry': ministry,
        'position': position,
        'period': Timestamp.fromDate(period),
        'attendance': attendance,
        'summary': summary,
        'challenges': challenges,
        'needs': needs,
        'status': ReportStatus.sent.name,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
