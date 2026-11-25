// These stand-ins have to implement Firestore's sealed classes to replace them.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/push_providers.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/notifications/widgets/push_opt_in_card.dart';
import 'package:church_cms/services/push_service.dart';

// ---- a stand-in for the browser ----
class _FakeGateway implements PushGateway {
  _FakeGateway({
    this.supported = true,
    this.current = PushPermission.undetermined,
    this.afterPrompt = PushPermission.granted,
    this.deviceToken = 'tok-phone',
  });

  bool supported;
  PushPermission current;
  PushPermission afterPrompt;
  String? deviceToken;
  int prompts = 0;
  int tokensDeleted = 0;
  final vapidKeysUsed = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    prompts++;
    current = afterPrompt;
    return current;
  }

  @override
  Future<String?> token(String vapidKey) async {
    vapidKeysUsed.add(vapidKey);
    return deviceToken;
  }

  @override
  Future<void> deleteToken() async => tokensDeleted++;
}

// ---- a stand-in for Firestore's `push_tokens` collection ----
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data);
  final Map<String, dynamic>? _data;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this._store, this._id);
  final Map<String, Map<String, dynamic>> _store;
  final String _id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async =>
      _Snapshot(_store[_id]);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      _store[_id] = data;
  @override
  Future<void> delete() async => _store.remove(_id);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this._store);
  final Map<String, Map<String, dynamic>> _store;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Doc(_store, path!);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Firestore implements FirebaseFirestore {
  final tokens = <String, Map<String, dynamic>>{};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'push_tokens');
    return _Collection(tokens);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

PushService _service(PushGateway g, _Firestore f, {String key = 'vapid-key'}) =>
    PushService(gateway: g, firestore: f, vapidKey: key);

void main() {
  group('where things stand', () {
    test('the feature is hidden until the notification key exists', () async {
      final g = _FakeGateway();
      expect(await _service(g, _Firestore(), key: '').state('u1'), PushState.notConfigured);
      expect(g.prompts, 0);
    });

    test('a browser that cannot show notifications is said to be unsupported', () async {
      expect(await _service(_FakeGateway(supported: false), _Firestore()).state('u1'),
          PushState.unsupported);
    });

    test('a refusal in the browser is "blocked"', () async {
      expect(
          await _service(_FakeGateway(current: PushPermission.denied), _Firestore()).state('u1'),
          PushState.blocked);
    });

    test('before anyone has been asked it is off, and asking is not done just to look', () async {
      final g = _FakeGateway();
      expect(await _service(g, _Firestore()).state('u1'), PushState.off);
      expect(g.prompts, 0);
    });

    test('allowed but this device is not registered is off', () async {
      expect(
          await _service(_FakeGateway(current: PushPermission.granted), _Firestore()).state('u1'),
          PushState.off);
    });

    test('allowed and registered for this person is on', () async {
      final f = _Firestore()..tokens['tok-phone'] = {'uid': 'u1'};
      expect(await _service(_FakeGateway(current: PushPermission.granted), f).state('u1'),
          PushState.on);
    });

    test('a device registered to someone else is not on for this person', () async {
      final f = _Firestore()..tokens['tok-phone'] = {'uid': 'someone-else'};
      expect(await _service(_FakeGateway(current: PushPermission.granted), f).state('u1'),
          PushState.off);
    });
  });

  group('turning alerts on', () {
    test('asks the browser, then registers the device for the person', () async {
      final g = _FakeGateway();
      final f = _Firestore();
      expect(await _service(g, f).enable('u1'), PushState.on);
      expect(g.prompts, 1);
      expect(g.vapidKeysUsed, ['vapid-key']);
      expect(f.tokens.keys, ['tok-phone']);
      expect(f.tokens['tok-phone']!['uid'], 'u1');
      expect(f.tokens['tok-phone']!.containsKey('updatedAt'), isTrue);
    });

    test('does not ask again when the browser already allows it', () async {
      final g = _FakeGateway(current: PushPermission.granted);
      final f = _Firestore();
      expect(await _service(g, f).enable('u1'), PushState.on);
      expect(g.prompts, 0);
    });

    test('a "no" at the prompt registers nothing', () async {
      final g = _FakeGateway(afterPrompt: PushPermission.denied);
      final f = _Firestore();
      expect(await _service(g, f).enable('u1'), PushState.blocked);
      expect(f.tokens, isEmpty);
    });

    test('closing the prompt without answering registers nothing', () async {
      final g = _FakeGateway(afterPrompt: PushPermission.undetermined);
      final f = _Firestore();
      expect(await _service(g, f).enable('u1'), PushState.off);
      expect(f.tokens, isEmpty);
    });

    test('a device that cannot get an address registers nothing', () async {
      final g = _FakeGateway(current: PushPermission.granted, deviceToken: null);
      final f = _Firestore();
      expect(await _service(g, f).enable('u1'), PushState.off);
      expect(f.tokens, isEmpty);
    });

    test('nothing happens without the key, or in an unsupported browser', () async {
      final f = _Firestore();
      expect(await _service(_FakeGateway(), f, key: '').enable('u1'), PushState.notConfigured);
      expect(await _service(_FakeGateway(supported: false), f).enable('u1'), PushState.unsupported);
      expect(f.tokens, isEmpty);
    });

    test('signing in on a phone another person used takes it over', () async {
      final g = _FakeGateway(current: PushPermission.granted);
      final f = _Firestore()..tokens['tok-phone'] = {'uid': 'u1'};
      await _service(g, f).enable('u2');
      expect(f.tokens['tok-phone']!['uid'], 'u2');
    });
  });

  group('turning alerts off', () {
    test('removes the device from the list and forgets its address', () async {
      final g = _FakeGateway(current: PushPermission.granted);
      final f = _Firestore()..tokens['tok-phone'] = {'uid': 'u1'};
      await _service(g, f).disable();
      expect(f.tokens, isEmpty);
      expect(g.tokensDeleted, 1);
    });

    test('does nothing when the feature is not set up', () async {
      final g = _FakeGateway(current: PushPermission.granted);
      await _service(g, _Firestore(), key: '').disable();
      expect(g.tokensDeleted, 0);
    });

    test('never asks for permission just to turn off', () async {
      final g = _FakeGateway();
      await _service(g, _Firestore()).disable();
      expect(g.prompts, 0);
    });

    test('forgetting the device on sign-out never throws', () async {
      final g = _ThrowingGateway();
      await _service(g, _Firestore()).forgetDevice(); // completes without an error
    });
  });

  group('the card on the Notifications screen', () {
    late _FakePushService service;

    Future<void> pump(WidgetTester tester, _FakePushService s, {String? uid = 'u1'}) async {
      service = s;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(s),
          currentUserIdProvider.overrideWithValue(uid),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: SingleChildScrollView(child: PushOptInCard()))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('is not shown until the key is set up', (tester) async {
      await pump(tester, _FakePushService(PushState.notConfigured));
      expect(find.byKey(const Key('push-card')), findsNothing);
    });

    testWidgets('offers to turn alerts on', (tester) async {
      await pump(tester, _FakePushService(PushState.off));
      expect(find.text('Get alerts on this phone'), findsOneWidget);
      expect(find.byKey(const Key('push-on')), findsOneWidget);
    });

    testWidgets('turning on asks the service and then shows they are on', (tester) async {
      await pump(tester, _FakePushService(PushState.off, enableTo: PushState.on));
      await tester.tap(find.byKey(const Key('push-on')));
      await tester.pumpAndSettle();
      expect(service.enabledFor, ['u1']);
      expect(find.text('Alerts are on for this phone'), findsOneWidget);
      expect(find.byKey(const Key('push-off')), findsOneWidget);
      expect(find.byKey(const Key('push-on')), findsNothing);
    });

    testWidgets('a "no" in the browser explains how to undo it', (tester) async {
      await pump(tester, _FakePushService(PushState.off, enableTo: PushState.blocked));
      await tester.tap(find.byKey(const Key('push-on')));
      await tester.pumpAndSettle();
      expect(find.text('Alerts are blocked'), findsOneWidget);
      expect(find.textContaining('Allow them in'), findsOneWidget);
      expect(find.byKey(const Key('push-on')), findsNothing);
    });

    testWidgets('already blocked shows the explanation straight away', (tester) async {
      await pump(tester, _FakePushService(PushState.blocked));
      expect(find.text('Alerts are blocked'), findsOneWidget);
    });

    testWidgets('an unsupported browser is told what to do on an iPhone', (tester) async {
      await pump(tester, _FakePushService(PushState.unsupported));
      expect(find.text('Alerts are not available here'), findsOneWidget);
      expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    });

    testWidgets('turning off asks the service and offers to turn on again', (tester) async {
      await pump(tester, _FakePushService(PushState.on));
      await tester.tap(find.byKey(const Key('push-off')));
      await tester.pumpAndSettle();
      expect(service.disabled, 1);
      expect(find.byKey(const Key('push-on')), findsOneWidget);
    });

    testWidgets('a failure to turn on is said plainly', (tester) async {
      await pump(tester, _FakePushService(PushState.off, enableFails: true));
      await tester.tap(find.byKey(const Key('push-on')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('push-error')), findsOneWidget);
      expect(find.byKey(const Key('push-on')), findsOneWidget); // can try again
    });

    testWidgets('shows nothing when it cannot tell where things stand', (tester) async {
      await pump(tester, _FakePushService(PushState.off, stateFails: true));
      expect(find.byKey(const Key('push-card')), findsNothing);
    });

    testWidgets('shows nothing when nobody is signed in', (tester) async {
      await pump(tester, _FakePushService(PushState.off), uid: null);
      expect(find.byKey(const Key('push-card')), findsNothing);
    });
  });

  group('signing out', () {
    test('forgets this device first, then signs out', () async {
      final order = <String>[];
      final container = ProviderContainer(overrides: [
        pushServiceProvider.overrideWithValue(_FakePushService(PushState.on, log: order)),
        firebaseAuthProvider.overrideWithValue(_FakeAuth(order)),
      ]);
      addTearDown(container.dispose);
      await container.read(signOutProvider)();
      expect(order, ['forget', 'signOut']);
    });

    test('still signs out when forgetting the device fails', () async {
      final order = <String>[];
      final container = ProviderContainer(overrides: [
        pushServiceProvider
            .overrideWithValue(_FakePushService(PushState.on, log: order, forgetFails: true)),
        firebaseAuthProvider.overrideWithValue(_FakeAuth(order)),
      ]);
      addTearDown(container.dispose);
      await container.read(signOutProvider)();
      expect(order, ['forget', 'signOut']);
    });
  });
}

class _ThrowingGateway implements PushGateway {
  @override
  Future<bool> isSupported() async => throw StateError('browser exploded');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePushService implements PushService {
  _FakePushService(
    this._state, {
    this.enableTo,
    this.enableFails = false,
    this.stateFails = false,
    this.forgetFails = false,
    List<String>? log,
  }) : _log = log;

  PushState _state;
  final PushState? enableTo;
  final bool enableFails;
  final bool stateFails;
  final bool forgetFails;
  final List<String>? _log;
  final enabledFor = <String>[];
  int disabled = 0;

  @override
  Future<PushState> state(String uid) async {
    if (stateFails) throw StateError('cannot tell');
    return _state;
  }

  @override
  Future<PushState> enable(String uid) async {
    enabledFor.add(uid);
    if (enableFails) throw StateError('nope');
    return _state = enableTo ?? PushState.on;
  }

  @override
  Future<void> disable() async => disabled++;

  @override
  Future<void> forgetDevice() async {
    _log?.add('forget');
    if (forgetFails) throw StateError('cannot forget');
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAuth implements FirebaseAuth {
  _FakeAuth(this._log);
  final List<String> _log;
  @override
  Future<void> signOut() async => _log.add('signOut');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
