// These stand-ins have to implement Firestore's sealed classes to replace them.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/services/role_request_service.dart';

/// One user profile, with the writes made to it.
class _Profile {
  _Profile(this.data);
  Map<String, dynamic> data;

  /// What was done, in order: `read`, `write in transaction`, `write`.
  final log = <String>[];
  final writes = <Map<Object, Object?>>[];

  /// Applies an update the way Firestore would, for the sentinels used here.
  void apply(Map<Object, Object?> update) {
    writes.add(update);
    update.forEach((key, value) {
      final k = key as String;
      if (value is List) {
        data[k] = value;
      } else if (value is FieldValue) {
        // The service only uses delete() inside a decision; ask() uses
        // arrayUnion, which the test checks by looking at what was sent.
        data.remove(k);
      } else {
        data[k] = value;
      }
    });
  }
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data);
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic>? data() => {..._data};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.profile);
  final _Profile profile;
  @override
  Future<void> update(Map<Object, Object?> data) async {
    profile.log.add('write');
    profile.writes.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.profile);
  final _Profile profile;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'u1');
    return _Doc(profile);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Transaction implements Transaction {
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> documentReference) async {
    final profile = (documentReference as _Doc).profile;
    profile.log.add('read');
    return _Snapshot(profile.data) as DocumentSnapshot<T>;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    final profile = (documentReference as _Doc).profile;
    profile.log.add('write in transaction');
    profile.apply(data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.profile);
  final _Profile profile;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return _Collection(profile);
  }

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
          {Duration timeout = const Duration(seconds: 30), int maxAttempts = 5}) =>
      transactionHandler(_Transaction());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  _Profile asking() => _Profile({
        'name': 'Mary',
        'role': 'member',
        'requestedRoles': ['elder', 'finance', 'secretariat'],
      });

  test('approving reads and writes inside one transaction', () async {
    final profile = asking();
    await RoleRequestService(_Firestore(profile)).approve('u1', UserRole.elder);
    expect(profile.log, ['read', 'write in transaction']);
  });

  test('three quick approvals end with all three roles, none lost', () async {
    final profile = asking();
    final service = RoleRequestService(_Firestore(profile));
    await service.approve('u1', UserRole.elder);
    await service.approve('u1', UserRole.finance);
    await service.approve('u1', UserRole.secretariat);
    expect(profile.data['roles'], containsAll(['elder', 'finance', 'secretariat']));
    expect(profile.data['roles'], hasLength(3));
    expect(profile.data.containsKey('requestedRoles'), isFalse);
    final access = UserAccess.fromData(profile.data);
    expect(access.canManageGiving, isTrue);
    expect(access.canWriteServiceReports, isTrue);
    expect(access.canManageAttendance, isTrue);
  });

  test('declining one leaves the others waiting and grants nothing', () async {
    final profile = asking();
    await RoleRequestService(_Firestore(profile)).decline('u1', UserRole.finance);
    expect(profile.data.containsKey('roles'), isFalse);
    expect(profile.data['requestedRoles'], ['elder', 'secretariat']);
    expect(UserAccess.fromData(profile.data).canViewGiving, isFalse);
  });

  test('asking adds to the list on the person\'s own profile only', () async {
    final profile = asking();
    await RoleRequestService(_Firestore(profile))
        .ask('u1', {UserRole.hospitality, UserRole.admin});
    expect(profile.log, ['write']);
    // only the list is written: nothing that could grant a role
    expect(profile.writes.single.keys, ['requestedRoles']);
    expect(profile.writes.single['requestedRoles'], isA<FieldValue>());
  });
}
