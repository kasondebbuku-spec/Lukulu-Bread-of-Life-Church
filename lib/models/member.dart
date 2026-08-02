import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name;
  final String email;
  final String phone;

  const Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Member(
      id: doc.id,
      name: data['name'] as String? ?? 'No name',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
      };
}
