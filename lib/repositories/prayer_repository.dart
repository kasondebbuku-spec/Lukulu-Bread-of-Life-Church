import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/prayer_request.dart';

class PrayerRepository extends FirestoreRepository<PrayerRequest> {
  PrayerRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.prayerRequests);

  /// Everything this person may read: their own requests, plus any that were
  /// shared with one of [audiences] (empty for an ordinary member).
  ///
  /// Firestore rules do not filter, so each query has to ask only for what the
  /// rules allow; the two results are merged here. Not named `watchAll` --
  /// incompatible (filtered) signature vs the base class's no-arg method.
  Stream<List<PrayerRequest>> watchVisible({
    required String? userId,
    required Set<PrayerAudience> audiences,
  }) {
    final queries = <Query<Map<String, dynamic>>>[
      if (userId != null) col.where('userId', isEqualTo: userId),
      if (audiences.isNotEmpty)
        col.where('audience', whereIn: audiences.map((a) => a.value).toList()),
    ];
    return mergeSnapshots(queries.map((q) =>
        q.snapshots().map((s) => s.docs.map(fromDoc).toList())));
  }

  /// Combines several list streams into one list that updates whenever any of
  /// them does. Waits until every source has answered once, so the screen never
  /// flashes a half-loaded list.
  static Stream<List<PrayerRequest>> mergeSnapshots(
      Iterable<Stream<List<PrayerRequest>>> sources) {
    final streams = sources.toList();
    if (streams.isEmpty) return Stream.value(const []);

    late StreamController<List<PrayerRequest>> controller;
    final subscriptions = <StreamSubscription<List<PrayerRequest>>>[];
    controller = StreamController<List<PrayerRequest>>(
      onListen: () {
        final latest = List<List<PrayerRequest>?>.filled(streams.length, null);
        var finished = 0;
        for (var i = 0; i < streams.length; i++) {
          subscriptions.add(streams[i].listen(
            (list) {
              latest[i] = list;
              if (latest.every((l) => l != null)) {
                controller.add(PrayerRequest.mergeNewestFirst(latest.cast()));
              }
            },
            onError: controller.addError,
            // Live queries never end; this only matters for finite sources.
            onDone: () {
              if (++finished == streams.length) controller.close();
            },
          ));
        }
      },
      onCancel: () async {
        for (final s in subscriptions) {
          await s.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  PrayerRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PrayerRequest.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(PrayerRequest request) => request.toMap();

  Future<void> updateStatus(String id, String status) =>
      col.doc(id).update({'status': status});

  /// Rewords a request and, when [audience] is given, changes who may read it
  /// (the author may do this; see firestore.rules).
  Future<void> updateDetails(String id,
          {required String text, PrayerAudience? audience}) =>
      col.doc(id).update({
        'request': text,
        if (audience != null) 'audience': audience.value,
      });
}
