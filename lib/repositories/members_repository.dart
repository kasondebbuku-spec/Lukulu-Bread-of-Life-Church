import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';

class MembersRepository {
  MembersRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('members');

  Stream<List<Member>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Member.fromDoc).toList());

  Future<void> add(Member member) =>
      _col.add({...member.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> update(String id, Member member) => _col.doc(id).update(member.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}
