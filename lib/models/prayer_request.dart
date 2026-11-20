import 'package:cloud_firestore/cloud_firestore.dart';

/// Who may read a prayer request, chosen by the member who wrote it.
/// Mirrors `canSeePrayer` in firestore.rules -- keep in sync.
enum PrayerAudience {
  pastor('pastor', 'Pastor only', 'Only the Pastor (and you) can read this.'),
  pastorElders('pastor_elders', 'Pastor and Elders',
      'The Pastor and the Elders (and you) can read this.'),
  leaders('leaders', 'All leaders',
      'Pastor, Elders, Deacons, Deaconesses, Admin and Secretariat can read this.');

  const PrayerAudience(this.value, this.label, this.description);

  /// What is stored in the database.
  final String value;
  final String label;
  final String description;

  /// The most private choice, used when a member does not pick one.
  static const defaultForNew = PrayerAudience.pastor;

  /// A request written before members could choose has no audience. It was
  /// visible to every leader, so it keeps that meaning.
  static PrayerAudience fromValue(String? raw) => PrayerAudience.values
      .firstWhere((a) => a.value == raw, orElse: () => PrayerAudience.leaders);
}

class PrayerRequest {
  final String id;
  final String userId;
  final String userName;
  final String request;
  final String status;
  final PrayerAudience audience;
  final DateTime? createdAt;

  const PrayerRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.request,
    required this.status,
    this.audience = PrayerAudience.defaultForNew,
    this.createdAt,
  });

  bool get isAnswered => status == 'answered';

  factory PrayerRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return PrayerRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Anonymous',
      request: data['request'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      audience: PrayerAudience.fromValue(data['audience'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'request': request,
        'status': status,
        'audience': audience.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Newest first; a request still waiting for its server timestamp is newest.
  static int newestFirst(PrayerRequest a, PrayerRequest b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return y.compareTo(x);
  }

  /// One list from several query results: each request once, newest first.
  static List<PrayerRequest> mergeNewestFirst(
      Iterable<List<PrayerRequest>> lists) {
    final byId = <String, PrayerRequest>{};
    for (final list in lists) {
      for (final request in list) {
        byId[request.id] = request;
      }
    }
    return byId.values.toList()..sort(newestFirst);
  }
}
