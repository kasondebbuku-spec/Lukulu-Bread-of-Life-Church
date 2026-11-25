import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/audit_actor_provider.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/notifications_provider.dart';
import 'package:church_cms/core/providers/pledge_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/dashboard/widgets/pledge_reminder_banner.dart';
import 'package:church_cms/features/giving/screens/pledges_screen.dart';
import 'package:church_cms/features/giving/widgets/my_pledges_section.dart';
import 'package:church_cms/features/members/screens/account_roles_screen.dart';
import 'package:church_cms/models/app_notification.dart';
import 'package:church_cms/models/audit_entry.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/pledge.dart';
import 'package:church_cms/repositories/pledge_repository.dart';
import 'package:church_cms/repositories/repository_providers.dart';

// Today for the pure tests: a fixed Wednesday.
final _now = DateTime(2026, 12, 2, 15, 30);

DateTime _inDays(int n) => DateTime(_now.year, _now.month, _now.day + n);

Pledge _pledge(
  String id, {
  String user = 'u1',
  double amount = 500,
  DateTime? madeOn,
  DateTime? due,
  PledgeStatus status = PledgeStatus.open,
  String name = 'Ruth Banda',
}) =>
    Pledge(
      id: id,
      userId: user,
      memberName: name,
      amount: amount,
      madeOn: madeOn ?? _inDays(-30),
      dueDate: due ?? _inDays(30),
      status: status,
    );

GivingRecord _gift(double amount, DateTime on,
        {String? user = 'u1',
        GivingCategory? category = GivingCategory.pledge,
        String currency = 'ZMW'}) =>
    GivingRecord(
      id: 'g${amount}_${on.day}',
      memberName: 'x',
      memberUserId: user,
      amount: amount,
      currency: currency,
      date: on,
      category: category,
    );

PledgeProgress _one(Pledge p, List<GivingRecord> gifts) =>
    pledgeProgress(pledges: [p], payments: gifts, now: _now).single;

class _FakePledgeRepository implements PledgeRepository {
  final added = <Pledge>[];
  final changed = <({String id, double amount, DateTime due, String note})>[];
  final cancelled = <String>[];

  @override
  Future<void> add(Pledge item) async => added.add(item);

  @override
  Future<void> change(String id,
          {required double amount,
          required DateTime dueDate,
          required String note}) async =>
      changed.add((id: id, amount: amount, due: dueDate, note: note));

  @override
  Future<void> cancel(String id) async => cancelled.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('how much of a pledge has been given', () {
    test('counts Pledge giving linked to the member, since the pledge was made', () {
      final p = _one(_pledge('a'), [
        _gift(200, _inDays(-10)),
        _gift(50, _inDays(-2)),
      ]);
      expect(p.paid, 250);
      expect(p.remaining, 250);
      expect(p.fraction, 0.5);
    });

    test('ignores giving that is not a pledge payment', () {
      final p = _one(_pledge('a'), [
        _gift(100, _inDays(-5), category: GivingCategory.tithe),
        _gift(100, _inDays(-5), category: null),
        _gift(100, _inDays(-5), currency: 'USD'),
        _gift(100, _inDays(-5), user: 'someone-else'),
        _gift(100, _inDays(-5), user: null),
        _gift(100, _inDays(-40)), // before the pledge was made
      ]);
      expect(p.paid, 0);
    });

    test('counts a gift made on the very day the pledge was made', () {
      final p = _one(_pledge('a', madeOn: _inDays(-3)), [_gift(80, _inDays(-3))]);
      expect(p.paid, 80);
    });

    test('goes to the oldest pledge first and the surplus rolls on', () {
      final older = _pledge('old', amount: 300, madeOn: _inDays(-60));
      final newer = _pledge('new', amount: 500, madeOn: _inDays(-20));
      final result = pledgeProgress(
          pledges: [newer, older],
          payments: [_gift(400, _inDays(-10))],
          now: _now);
      final byId = {for (final r in result) r.pledge.id: r};
      expect(byId['old']!.paid, 300);
      expect(byId['old']!.state, PledgeState.fulfilled);
      expect(byId['new']!.paid, 100);
      expect(byId['new']!.remaining, 400);
    });

    test('does not give a newer pledge money from before it existed', () {
      final older = _pledge('old', amount: 100, madeOn: _inDays(-60));
      final newer = _pledge('new', amount: 500, madeOn: _inDays(-5));
      final result = pledgeProgress(
          pledges: [older, newer],
          payments: [_gift(300, _inDays(-30))], // only the older pledge existed
          now: _now);
      final byId = {for (final r in result) r.pledge.id: r};
      expect(byId['old']!.paid, 100);
      expect(byId['new']!.paid, 0); // the leftover 200 cannot go back in time
    });

    test('never shows more than was pledged', () {
      final p = _one(_pledge('a', amount: 100), [_gift(250, _inDays(-1))]);
      expect(p.paid, 100);
      expect(p.remaining, 0);
      expect(p.state, PledgeState.fulfilled);
    });

    test('a cancelled pledge takes nothing, so the next one gets the money', () {
      final gone = _pledge('gone', amount: 300, madeOn: _inDays(-60), status: PledgeStatus.cancelled);
      final live = _pledge('live', amount: 500, madeOn: _inDays(-40));
      final result = pledgeProgress(
          pledges: [gone, live], payments: [_gift(200, _inDays(-10))], now: _now);
      final byId = {for (final r in result) r.pledge.id: r};
      expect(byId['gone']!.state, PledgeState.cancelled);
      expect(byId['gone']!.paid, 0);
      expect(byId['live']!.paid, 200);
    });

    test('two members\' pledges never share payments', () {
      final result = pledgeProgress(
        pledges: [_pledge('a', user: 'u1'), _pledge('b', user: 'u2')],
        payments: [_gift(500, _inDays(-3), user: 'u1')],
        now: _now,
      );
      final byId = {for (final r in result) r.pledge.id: r};
      expect(byId['a']!.state, PledgeState.fulfilled);
      expect(byId['b']!.paid, 0);
    });
  });

  group('where a pledge stands', () {
    PledgeState stateOn(int dueInDays, {double paid = 0}) => _one(
            _pledge('a', due: _inDays(dueInDays)),
            paid > 0 ? [_gift(paid, _inDays(-1))] : const [])
        .state;

    test('on track when it is more than a week away', () {
      expect(stateOn(8), PledgeState.upcoming);
      expect(stateOn(60), PledgeState.upcoming);
    });
    test('due soon from a week out, including the due day itself', () {
      expect(stateOn(7), PledgeState.dueSoon);
      expect(stateOn(1), PledgeState.dueSoon);
      expect(stateOn(0), PledgeState.dueSoon);
    });
    test('overdue the day after, until it is given', () {
      expect(stateOn(-1), PledgeState.overdue);
      expect(stateOn(-30), PledgeState.overdue);
      expect(stateOn(-1, paid: 500), PledgeState.fulfilled);
    });
    test('fulfilled whenever it has been given in full, early or late', () {
      expect(stateOn(40, paid: 500), PledgeState.fulfilled);
      expect(stateOn(3, paid: 500), PledgeState.fulfilled);
    });
    test('only the unfinished ones near or past their date need a reminder', () {
      expect(_one(_pledge('a', due: _inDays(7)), const []).needsReminder, isTrue);
      expect(_one(_pledge('a', due: _inDays(-4)), const []).needsReminder, isTrue);
      expect(_one(_pledge('a', due: _inDays(20)), const []).needsReminder, isFalse);
      expect(_one(_pledge('a', due: _inDays(-4)), [_gift(500, _inDays(-1))]).needsReminder,
          isFalse);
    });
    test('lists overdue first, then soonest due, then the finished ones', () {
      final result = pledgeProgress(
        pledges: [
          _pledge('upcoming', due: _inDays(40)),
          _pledge('done', due: _inDays(5), amount: 10),
          _pledge('soon', due: _inDays(3)),
          _pledge('late', due: _inDays(-2)),
          _pledge('cancelled', due: _inDays(1), status: PledgeStatus.cancelled),
        ],
        payments: [_gift(10, _inDays(-1))],
        now: _now,
      );
      // 'done' took the K10 payment first (oldest-first has no say here: one pledge fits).
      expect(result.map((r) => r.pledge.id),
          ['late', 'soon', 'upcoming', 'done', 'cancelled']);
    });
  });

  group('the reminder wording', () {
    String say(int dueInDays, {bool staff = false}) => _one(
            _pledge('a', due: _inDays(dueInDays)), [_gift(200, _inDays(-1))])
        .reminderText(forStaff: staff);

    test('says how much is left and when', () {
      expect(say(5),
          'ZMW 300.00 still to give on your ZMW 500.00 pledge, due Dec 7, 2026 (in 5 days).');
      expect(say(1), contains('due tomorrow (Dec 3, 2026)'));
      expect(say(0), contains('due today (Dec 2, 2026)'));
      expect(say(-1), contains('was due yesterday (Dec 1, 2026)'));
      expect(say(-9), contains('was due Nov 23, 2026 (9 days ago)'));
    });
    test('names the member when it is for someone else to read', () {
      expect(say(5, staff: true), contains("Ruth Banda's ZMW 500.00 pledge"));
    });
  });

  test('a pledge is saved with its amount, dates and who entered it', () {
    final map = _pledge('a').toMap();
    expect(map['userId'], 'u1');
    expect(map['amount'], 500);
    expect(map['status'], 'open');
    expect(map.keys.toSet(), {
      'userId', 'memberName', 'amount', 'madeOn', 'dueDate', 'note', 'status',
      'createdBy', 'createdAt',
    });
    // Whether it is fulfilled is never stored.
    expect(map.containsKey('paid'), isFalse);
  });

  group('on the Home screen and the bell', () {
    final overdue = _one(_pledge('late', due: _inDays(-4)), [_gift(100, _inDays(-10))]);
    final soon = _one(_pledge('soon', amount: 300, due: _inDays(3)), const []);
    final far = _one(_pledge('far', due: _inDays(40)), const []);

    Future<void> pumpBanner(WidgetTester tester, List<PledgeProgress> items) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [myPledgeProgressProvider.overrideWithValue(items)],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: PledgeReminderBanner())),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a pledge due within a week or late shows a reminder', (tester) async {
      await pumpBanner(tester, [soon]);
      expect(find.text('Pledge reminder'), findsOneWidget);
      expect(find.textContaining('ZMW 300.00 still to give on your ZMW 300.00 pledge'),
          findsOneWidget);
    });

    testWidgets('the most urgent one leads, and the rest are counted', (tester) async {
      await pumpBanner(tester, [overdue, soon]);
      expect(find.textContaining('was due'), findsOneWidget);
      expect(find.text('and 1 more pledge to look at'), findsOneWidget);
    });

    testWidgets('nothing shows when no pledge needs a nudge', (tester) async {
      await pumpBanner(tester, [far]);
      expect(find.text('Pledge reminder'), findsNothing);
      await pumpBanner(tester, const []);
      expect(find.text('Pledge reminder'), findsNothing);
    });

    ProviderContainer container(UserAccess role, List<PledgeProgress> items) {
      final c = ProviderContainer(overrides: [
        userRoleProvider.overrideWith((ref) => Stream.value(role)),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        announcementsProvider.overrideWith((ref) => Stream.value([])),
        eventsProvider.overrideWith((ref) => Stream.value([])),
        incomeFormsProvider.overrideWith((ref) => Stream.value([])),
        myPledgeProgressProvider.overrideWithValue(items),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      for (final p in [userRoleProvider, announcementsProvider, eventsProvider, incomeFormsProvider]) {
        c.listen(p, (_, __) {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('the bell carries a reminder for a pledge that is due soon or late', () async {
      // These two use today's real date, as the app itself does.
      PledgeProgress live(Pledge p) =>
          pledgeProgress(pledges: [p], payments: const [], now: DateTime.now()).single;
      final dueSoon = live(_pledge('soon',
          amount: 300, due: DateTime.now().add(const Duration(days: 3))));
      final late = live(_pledge('late',
          due: DateTime.now().subtract(const Duration(days: 4))));
      final c = container(UserAccess.member, [dueSoon, late]);
      await settle(c);
      final items = c.read(notificationsProvider);
      expect(items, hasLength(2));
      expect(items.every((n) => n.kind == NotificationKind.pledge), isTrue);
      expect(items.every((n) => n.title == 'Pledge reminder'), isTrue);
      expect(items.any((n) => n.detail.contains('was due')), isTrue);
      expect(items.any((n) => n.detail.contains('(in 3 days)') || n.detail.contains('(in 2 days)')), isTrue);
    });

    test('a pledge that is far off, or already given, is not in the bell', () async {
      final c = container(UserAccess.member, [far]);
      await settle(c);
      expect(c.read(notificationsProvider), isEmpty);
    });
  });

  group('My Pledges', () {
    Future<_FakePledgeRepository> pump(WidgetTester tester,
        {List<Pledge> pledges = const [],
        List<GivingRecord> gifts = const []}) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakePledgeRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pledgeRepositoryProvider.overrideWithValue(repo),
          myPledgesProvider.overrideWith((ref) => Stream.value(pledges)),
          myGivingProvider.overrideWith((ref) => Stream.value(gifts)),
          currentUserIdProvider.overrideWithValue('u1'),
          displayNameProvider.overrideWithValue('Ruth Banda'),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: SingleChildScrollView(child: MyPledgesSection()))),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    Pledge live({double amount = 500, int dueIn = 30}) => Pledge(
          id: 'p1',
          userId: 'u1',
          memberName: 'Ruth Banda',
          amount: amount,
          madeOn: DateTime.now().subtract(const Duration(days: 20)),
          dueDate: DateTime.now().add(Duration(days: dueIn)),
          note: 'Building fund',
        );

    testWidgets('says so when there are none', (tester) async {
      await pump(tester);
      expect(find.text('You have no pledges yet. Tap New pledge to record one.'),
          findsOneWidget);
    });

    testWidgets('shows what was pledged, given and still to go', (tester) async {
      await pump(tester, pledges: [live()], gifts: [
        _gift(200, DateTime.now().subtract(const Duration(days: 5))),
      ]);
      expect(find.text('ZMW 500.00'), findsOneWidget);
      expect(find.text('Building fund'), findsOneWidget);
      expect(find.textContaining('ZMW 200.00 given'), findsOneWidget);
      expect(find.textContaining('ZMW 300.00 to go'), findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
    });

    testWidgets('a pledge given in full is marked fulfilled', (tester) async {
      await pump(tester, pledges: [live(amount: 100)], gifts: [
        _gift(100, DateTime.now().subtract(const Duration(days: 2))),
      ]);
      expect(find.text('Fulfilled'), findsOneWidget);
      expect(find.textContaining('Thank you'), findsOneWidget);
    });

    testWidgets('a late pledge is marked overdue', (tester) async {
      await pump(tester, pledges: [live(dueIn: -3)]);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('a cancelled pledge is not listed', (tester) async {
      await pump(tester, pledges: [
        Pledge(
            id: 'x', userId: 'u1', memberName: 'Ruth', amount: 999,
            madeOn: DateTime.now(), dueDate: DateTime.now(),
            status: PledgeStatus.cancelled),
      ]);
      expect(find.text('ZMW 999.00'), findsNothing);
      expect(find.text('You have no pledges yet. Tap New pledge to record one.'),
          findsOneWidget);
    });

    testWidgets('a member can make a pledge', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const Key('new-pledge')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '800');
      await tester.enterText(find.widgetWithText(TextFormField, 'What it is for (optional)'), 'Missions');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = repo.added.single;
      expect(saved.userId, 'u1');
      expect(saved.memberName, 'Ruth Banda');
      expect(saved.createdBy, 'Ruth Banda');
      expect(saved.amount, 800);
      expect(saved.note, 'Missions');
      expect(saved.status, PledgeStatus.open);
      // Made today, due in the future.
      final today = DateTime.now();
      expect(saved.madeOn, DateTime(today.year, today.month, today.day));
      expect(saved.dueDate.isAfter(saved.madeOn), isTrue);
      expect(find.text('Pledge recorded.'), findsOneWidget);
    });

    testWidgets('an amount is required, and must make sense', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const Key('new-pledge')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '99999999');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('That amount is too large'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('a member can change a pledge', (tester) async {
      final repo = await pump(tester, pledges: [live()]);
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      // The dialog opens with the current amount.
      final field = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'));
      expect(field.controller!.text, '500');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '700');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.changed.single.id, 'p1');
      expect(repo.changed.single.amount, 700);
      expect(repo.changed.single.note, 'Building fund');
    });

    testWidgets('a member can cancel a pledge, after confirming', (tester) async {
      final repo = await pump(tester, pledges: [live()]);
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel pledge'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty, reason: 'must confirm first');
      expect(find.text('Cancel this pledge?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty);

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel pledge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel pledge'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, ['p1']);
    });
  });

  group('the Finance Officer\'s list', () {
    final accounts = [
      const RegisteredAccount('u1', 'Ruth Banda', 'ruth@x.com', UserAccess.member),
      const RegisteredAccount('u2', 'Peter Kabwe', 'peter@x.com', UserAccess.member),
    ];

    Future<_FakePledgeRepository> pump(WidgetTester tester, UserAccess role,
        {List<PledgeProgress> items = const []}) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakePledgeRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pledgeRepositoryProvider.overrideWithValue(repo),
          userRoleProvider.overrideWith((ref) => Stream.value(role)),
          allPledgeProgressProvider.overrideWithValue(items),
          registeredAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
          auditActorProvider.overrideWithValue(const AuditActor(uid: 'f1', name: 'Mary Finance')),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const PledgesScreen()),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    final items = [
      _one(_pledge('a', due: _inDays(-3), name: 'Ruth Banda'), [_gift(100, _inDays(-10))]),
      _one(_pledge('b', user: 'u2', amount: 200, due: _inDays(40), name: 'Peter Kabwe'), const []),
    ];

    testWidgets('shows everyone\'s pledges with the totals still owing', (tester) async {
      await pump(tester, const UserAccess({UserRole.finance}), items: items);
      expect(find.text('2 pledges'), findsOneWidget);
      // 400 still owed by Ruth + 200 by Peter.
      expect(find.text('Still to be given: ZMW 600.00'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
      expect(find.text('Ruth Banda'), findsOneWidget);
      expect(find.text('Peter Kabwe'), findsOneWidget);
    });

    testWidgets('says so when there are none', (tester) async {
      await pump(tester, const UserAccess({UserRole.finance}));
      expect(find.textContaining('No pledges yet'), findsOneWidget);
    });

    testWidgets('Finance can record one for a member', (tester) async {
      final repo = await pump(tester, const UserAccess({UserRole.finance}), items: items);
      await tester.tap(find.byKey(const Key('record-pledge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<RegisteredAccount>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peter Kabwe (peter@x.com)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '250');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = repo.added.single;
      expect(saved.userId, 'u2'); // the member's, not Finance's
      expect(saved.memberName, 'Peter Kabwe');
      expect(saved.amount, 250);
      expect(saved.createdBy, 'Mary Finance');
    });

    testWidgets('a member must be chosen', (tester) async {
      final repo = await pump(tester, const UserAccess({UserRole.finance}), items: items);
      await tester.tap(find.byKey(const Key('record-pledge')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount pledged (ZMW)'), '250');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the member'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('the Pastor can see the list but not record or change', (tester) async {
      await pump(tester, const UserAccess({UserRole.pastor}), items: items);
      expect(find.text('Ruth Banda'), findsOneWidget);
      expect(find.byKey(const Key('record-pledge')), findsNothing);
      expect(find.byTooltip('Options'), findsNothing);
    });
  });
}
