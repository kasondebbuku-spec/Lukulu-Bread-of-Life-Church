import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/prayer/screens/prayer_screen.dart';
import 'package:church_cms/models/prayer_request.dart';
import 'package:church_cms/repositories/prayer_repository.dart';
import 'package:church_cms/repositories/repository_providers.dart';

/// Records what the screen asks the repository to do.
class _FakePrayerRepository implements PrayerRepository {
  final added = <PrayerRequest>[];
  final edits = <List<String>>[];
  final statuses = <List<String>>[];
  final deleted = <String>[];

  @override
  Future<void> add(PrayerRequest item) async => added.add(item);

  @override
  Future<void> updateText(String id, String text) async => edits.add([id, text]);

  @override
  Future<void> updateStatus(String id, String status) async =>
      statuses.add([id, status]);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PrayerRequest _request(String id, String owner, {String text = 'Pray for my family'}) =>
    PrayerRequest(
      id: id,
      userId: owner,
      userName: 'Owner $owner',
      request: text,
      status: 'pending',
    );

void main() {
  late _FakePrayerRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    required List<PrayerRequest> requests,
    UserAccess role = UserAccess.member,
    String userId = 'u1',
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _FakePrayerRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prayerRepositoryProvider.overrideWithValue(repo),
        prayerRequestsProvider.overrideWith((ref) => Stream.value(requests)),
        userRoleProvider.overrideWith((ref) => Stream.value(role)),
        currentUserIdProvider.overrideWithValue(userId),
        displayNameProvider.overrideWithValue('Ruth Banda'),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const PrayerScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the writing box is roomy, multi-line and has a length limit',
      (tester) async {
    await pump(tester, requests: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, greaterThanOrEqualTo(6));
    expect(field.maxLines, greaterThan(field.minLines!));
    expect(field.maxLength, prayerRequestMaxLength);
    expect(field.keyboardType, TextInputType.multiline);

    final box = tester.getSize(find.byType(TextField));
    expect(box.height, greaterThan(150), reason: 'was a cramped 3-line box');
    expect(box.width, greaterThan(400));
  });

  testWidgets('submitting posts the request under the user\'s name', (tester) async {
    await pump(tester, requests: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Healing for my mother  ');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(repo.added.single.request, 'Healing for my mother');
    expect(repo.added.single.userId, 'u1');
    expect(repo.added.single.userName, 'Ruth Banda');
    expect(find.text('Prayer request posted.'), findsOneWidget);
  });

  testWidgets('an empty request is not submitted', (tester) async {
    await pump(tester, requests: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Please write something'), findsOneWidget);
    expect(repo.added, isEmpty);
  });

  testWidgets('a member can edit their own request', (tester) async {
    await pump(tester, requests: [_request('r1', 'u1')]);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Pray for my family'); // pre-filled

    await tester.enterText(find.byType(TextField), 'Pray for my family and job');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.edits.single, ['r1', 'Pray for my family and job']);
  });

  testWidgets('saving an unchanged request does nothing', (tester) async {
    await pump(tester, requests: [_request('r1', 'u1')]);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.edits, isEmpty);
  });

  testWidgets('a member can mark their own request answered', (tester) async {
    await pump(tester, requests: [_request('r1', 'u1')]);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as answered'));
    await tester.pumpAndSettle();
    expect(repo.statuses.single, ['r1', 'answered']);
  });

  testWidgets('a member can delete their own request, after confirming',
      (tester) async {
    await pump(tester, requests: [_request('r1', 'u1')]);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty, reason: 'must confirm first');

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted.single, 'r1');
  });

  testWidgets('a leader can mark or delete anyone\'s request but not reword it',
      (tester) async {
    await pump(
      tester,
      requests: [_request('r2', 'someone-else')],
      role: const UserAccess({UserRole.elder}),
    );
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Mark as answered'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a member sees no options on a request that is not theirs',
      (tester) async {
    await pump(tester, requests: [_request('r3', 'someone-else')]);
    expect(find.byTooltip('Options'), findsNothing);
  });
}
