import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic Repository pattern for Firestore-backed entities.
///
/// Subclasses supply [fromDoc]/[toMap] and may override [watchAll] when
/// sorting or filtering differs (e.g. events sort by date, not createdAt).
abstract class FirestoreRepository<T> {
  FirestoreRepository(this._firestore, this.collectionPath);

  final FirebaseFirestore _firestore;
  final String collectionPath;

  /// Exposed for subclasses that need custom queries or batch writes.
  CollectionReference<Map<String, dynamic>> get col =>
      _firestore.collection(collectionPath);

  T fromDoc(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toMap(T item);

  Stream<List<T>> watchAll() => col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(fromDoc).toList());

  Future<void> add(T item) => col.add(toMap(item));

  Future<String> addAndGetId(T item) async {
    final ref = await col.add(toMap(item));
    return ref.id;
  }

  Future<void> update(String id, T item) => col.doc(id).update(toMap(item));

  Future<void> delete(String id) => col.doc(id).delete();
}
