import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/repositories/firestore_repository.dart';
import '../models/member.dart';

class MembersRepository extends FirestoreRepository<Member> {
  MembersRepository(FirebaseFirestore firestore)
      : super(firestore, FirestoreCollections.members);

  @override
  Member fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Member.fromDoc(doc);

  @override
  Map<String, dynamic> toMap(Member member) => {
        ...member.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
