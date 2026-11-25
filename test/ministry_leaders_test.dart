import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/ministry_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/leaders/screens/leaders_screen.dart';
import 'package:church_cms/features/leaders/screens/ministry_report_detail_screen.dart';
import 'package:church_cms/features/leaders/screens/ministry_reports_screen.dart';
import 'package:church_cms/models/ministry_position.dart';
import 'package:church_cms/models/ministry_report.dart';
import 'package:church_cms/repositories/ministry_report_repository.dart';
import 'package:church_cms/services/leader_directory_service.dart';
import 'package:church_cms/services/position_service.dart';

const _choir = MinistryPosition(ministry: 'Choir', title: 'Leader');
const _woi = MinistryPosition(ministry: 'Women of Integrity', title: 'Secretary');

UserAccess _access(Set<UserRole> roles, [List<MinistryPosition> positions = const []]) =>
    UserAccess(roles, positions: {for (final p in positions) p.key: p});

MinistryReport _report(
  String id, {
  String uid = 'u1',
  String author = 'Ruth Banda',
  MinistryPosition p = _choir,
  String summary = 'Rehearsed for the Christmas cantata.',
  bool reviewed = false,
  String note = '',
}) =>
    MinistryReport(
      id: id,
      authorUid: uid,
      authorName: author,
      ministryKey: p.key,
      ministry: p.ministry,
      position: p.title,
      period: DateTime(2026, 11, 22),
      attendance: 24,
      summary: summary,
      challenges: 'Few sopranos',
      needs: 'New hymn books',
      status: reviewed ? ReportStatus.reviewed : ReportStatus.sent,
      pastorNote: note,
      reviewedBy: reviewed ? 'Pastor Mwale' : '',
      reviewedAt: reviewed ? DateTime(2026, 11, 24) : null,
    );

class _FakeReports implements MinistryReportRepository {
  final added = <MinistryReport>[];
  final changed = <String>[];
  final deleted = <String>[];
  final reviewedWith = <({String id, String note, String reviewer})>[];
  bool failing = false;

  @override
  Future<void> add(MinistryReport item) async {
    if (failing) throw StateError('offline');
    added.add(item);
  }

  @override
  Future<void> change(String id,
      {required DateTime period,
      required int attendance,
      required String summary,
      required String challenges,
      required String needs}) async {
    changed.add('$id|$summary|$attendance');
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> markReviewed(String id,
          {required String note, required String reviewer}) async =>
      reviewedWith.add((id: id, note: note, reviewer: reviewer));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePositions implements PositionService {
  final requested = <MinistryPosition>[];
  @override
  Future<void> request(String uid, MinistryPosition position) async =>
      requested.add(position);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDirectory implements LeaderDirectoryService {
  int rebuilt = 0;
  @override
  Future<int> rebuild() async {
    rebuilt++;
    return 3;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget home, List<Override> overrides) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('u1'),
      displayNameProvider.overrideWithValue('Ruth Banda'),
      ...overrides,
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ministry positions', () {
    test('a ministry key is a short stable form of its name', () {
      expect(ministryKey('Choir'), 'choir');
      expect(ministryKey('Women of Integrity'), 'women-of-integrity');
      expect(ministryKey("  Men's Fellowship! "), 'men-s-fellowship');
      expect(ministryKey('???'), '');
    });

    test('a position is read from a saved map, or refused', () {
      expect(MinistryPosition.fromMap({'ministry': ' Choir ', 'title': 'Leader '}),
          _choir);
      expect(MinistryPosition.fromMap({'ministry': 'Choir'}), isNull);
      expect(MinistryPosition.fromMap({'ministry': '', 'title': 'Leader'}), isNull);
      expect(MinistryPosition.fromMap({'ministry': '???', 'title': 'Leader'}), isNull);
      expect(MinistryPosition.fromMap('Choir Leader'), isNull);
      expect(MinistryPosition.fromMap(null), isNull);
      expect(_choir.label, 'Choir · Leader');
    });

    test('the positions on a profile are read, skipping any that are damaged', () {
      final all = parsePositions({
        'choir': {'ministry': 'Choir', 'title': 'Leader'},
        'bad': {'ministry': 'Youth'},
        'worse': 'nonsense',
      });
      expect(all.keys, ['choir']);
      expect(parsePositions(null), isEmpty);
      expect(parsePositions([1, 2]), isEmpty);
    });

    test('the ministry and position text must be sensible', () {
      expect(validateMinistryText('', what: 'the ministry'), isNotNull);
      expect(validateMinistryText('   ', what: 'the position'), isNotNull);
      expect(validateMinistryText('x' * 61, what: 'the position'), isNotNull);
      expect(validateMinistryText('???', what: 'the ministry'), isNotNull);
      expect(validateMinistryText('Choir', what: 'the ministry'), isNull);
      expect(validateMinistryText('Leader', what: 'the position'), isNull);
    });
  });

  group('what a profile allows', () {
    test('positions are read from the profile', () {
      final a = UserAccess.fromData({
        'role': 'member',
        'positions': {'choir': {'ministry': 'Choir', 'title': 'Leader'}},
      });
      expect(a.hasPosition, isTrue);
      expect(a.positions['choir'], _choir);
      expect(UserAccess.fromData({'role': 'member'}).hasPosition, isFalse);
    });

    test('only the Pastor and Admin review reports', () {
      expect(_access({UserRole.pastor}).canReviewMinistryReports, isTrue);
      expect(_access({UserRole.admin}).canReviewMinistryReports, isTrue);
      for (final r in [UserRole.elder, UserRole.finance, UserRole.secretariat, UserRole.member]) {
        expect(_access({r}).canReviewMinistryReports, isFalse, reason: r.name);
      }
      // holding a position does not let you read other people's reports
      expect(_access({UserRole.member}, [_choir]).canReviewMinistryReports, isFalse);
    });

    test('a leader account is anyone with a church role or a position', () {
      expect(UserAccess.member.isLeaderAccount, isFalse);
      expect(_access({UserRole.member}, [_choir]).isLeaderAccount, isTrue);
      expect(_access({UserRole.deacon}).isLeaderAccount, isTrue);
    });
  });

  group('the leaders directory entry made from a profile', () {
    test('lists a church role with the contact', () {
      final p = LeaderDirectoryService.project({
        'name': 'Mary Banda',
        'email': 'mary@gmail.com',
        'roles': ['elder', 'member'],
        'phone': '260971234567',
      })!;
      expect(p.leader['name'], 'Mary Banda');
      expect(p.leader['roles'], ['elder']);
      expect(p.leader['positions'], isEmpty);
      expect(p.contact['email'], 'mary@gmail.com');
      expect(p.contact['phone'], '260971234567');
    });

    test('lists ministry positions', () {
      final p = LeaderDirectoryService.project({
        'name': 'Ruth Banda',
        'email': 'ruth@gmail.com',
        'role': 'member',
        'positions': {'choir': {'ministry': 'Choir', 'title': 'Leader'}},
      })!;
      expect(p.leader['roles'], isEmpty);
      expect(p.leader['positions'], [
        {'ministry': 'Choir', 'title': 'Leader'}
      ]);
    });

    test('never lists Admin or Member as a role', () {
      final p = LeaderDirectoryService.project({
        'name': 'Admin Person',
        'roles': ['admin', 'pastor'],
      })!;
      expect(p.leader['roles'], ['pastor']);
    });

    test('leaves out a plain member, and an Admin with nothing else', () {
      expect(LeaderDirectoryService.project({'name': 'Peter', 'role': 'member'}), isNull);
      expect(LeaderDirectoryService.project({'name': 'Root', 'roles': ['admin']}), isNull);
      expect(LeaderDirectoryService.project(null), isNull);
    });

    test('shows a phone number, never the made-up address behind it', () {
      final p = LeaderDirectoryService.project({
        'name': 'John Phiri',
        'email': '260971234567@phone.lukulu-bread-of-life.app',
        'phone': '260971234567',
        'roles': ['deacon'],
      })!;
      expect(p.contact.containsKey('email'), isFalse);
      expect(p.contact['phone'], '260971234567');
    });

    test('a leader with no contact has only the update stamp', () {
      final p = LeaderDirectoryService.project({'name': 'Ann', 'roles': ['elder']})!;
      expect(p.contact.keys, ['updatedAt']);
    });

    test('a nameless profile still gets a name', () {
      final p = LeaderDirectoryService.project({'roles': ['elder']})!;
      expect(p.leader['name'], 'Leader');
    });
  });

  group('the Leaders screen', () {
    final leaders = [
      const LeaderEntry(uid: 'p', name: 'Pastor Mwale', roles: [UserRole.pastor]),
      const LeaderEntry(uid: 'e', name: 'Elder Banda', roles: [UserRole.elder, UserRole.oversight]),
      const LeaderEntry(uid: 'c', name: 'Ruth Banda', positions: [_choir]),
      const LeaderEntry(uid: 'w', name: 'Grace Mulenga', positions: [_woi]),
    ];
    final contacts = {
      'p': const LeaderContact(phone: '260971234567', email: 'pastor@x.com'),
    };

    List<Override> base({
      UserAccess? access,
      Map<String, LeaderContact>? shownContacts,
      MinistryPosition? pending,
      _FakePositions? positions,
      _FakeDirectory? directory,
      List<LeaderEntry>? entries,
    }) =>
        [
          userRoleProvider.overrideWith((ref) => Stream.value(access ?? UserAccess.member)),
          leadersProvider.overrideWith((ref) => Stream.value(entries ?? leaders)),
          leaderContactsProvider
              .overrideWith((ref) => Stream.value(shownContacts ?? const {})),
          myPositionRequestProvider.overrideWith((ref) => Stream.value(pending)),
          positionServiceProvider.overrideWithValue(positions ?? _FakePositions()),
          leaderDirectoryServiceProvider.overrideWithValue(directory ?? _FakeDirectory()),
        ];

    testWidgets('lists church roles and ministries, name and position', (tester) async {
      await _pump(tester, const LeadersScreen(), base());
      expect(find.text('Pastor'), findsNWidgets(2)); // the heading and the person's role
      expect(find.text('Pastor Mwale'), findsOneWidget);
      expect(find.text('Elders'), findsOneWidget);
      expect(find.text('Financial Oversight'), findsNWidgets(2)); // heading and role
      // the Elder who is also Oversight appears under both
      expect(find.text('Elder Banda'), findsNWidgets(2));
      expect(find.text('Ministries'), findsOneWidget);
      expect(find.text('Choir'), findsOneWidget);
      expect(find.text('Leader, Choir'), findsOneWidget);
      expect(find.text('Women of Integrity'), findsOneWidget);
      expect(find.text('Secretary, Women of Integrity'), findsOneWidget);
    });

    testWidgets('a member sees no phone or email, and is told why', (tester) async {
      await _pump(tester, const LeadersScreen(), base());
      expect(find.textContaining('+260971234567'), findsNothing);
      expect(find.textContaining('pastor@x.com'), findsNothing);
      expect(find.textContaining('shown only to other leaders'), findsOneWidget);
    });

    testWidgets('a leader sees phone and email', (tester) async {
      await _pump(tester, const LeadersScreen(),
          base(access: _access({UserRole.deacon}), shownContacts: contacts));
      expect(find.textContaining('+260971234567'), findsOneWidget);
      expect(find.textContaining('pastor@x.com'), findsOneWidget);
      expect(find.textContaining('shown only to other leaders'), findsNothing);
    });

    testWidgets('says so when nobody is listed', (tester) async {
      await _pump(tester, const LeadersScreen(), base(entries: const []));
      expect(find.text('No leaders are listed yet.'), findsOneWidget);
    });

    testWidgets('a member does not see the refresh button', (tester) async {
      await _pump(tester, const LeadersScreen(), base());
      expect(find.byKey(const Key('refresh-directory')), findsNothing);
    });

    testWidgets('an Admin sees the refresh button, and it rebuilds the list', (tester) async {
      final dir = _FakeDirectory();
      await _pump(tester, const LeadersScreen(),
          base(access: _access({UserRole.admin}), directory: dir));
      await tester.tap(find.byKey(const Key('refresh-directory')));
      await tester.pumpAndSettle();
      expect(dir.rebuilt, 1);
      expect(find.text('Directory refreshed: 3 leaders.'), findsOneWidget);
    });

    testWidgets('anyone can ask for a ministry position', (tester) async {
      final positions = _FakePositions();
      await _pump(tester, const LeadersScreen(), base(positions: positions));
      await tester.tap(find.byKey(const Key('request-position')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ministry-choice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Women of Integrity').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ministry-title')), 'Treasurer');
      await tester.tap(find.byKey(const Key('send-position-request')));
      await tester.pumpAndSettle();

      expect(positions.requested.single,
          const MinistryPosition(ministry: 'Women of Integrity', title: 'Treasurer'));
      expect(find.textContaining('The Admin will approve'), findsOneWidget);
    });

    testWidgets('a ministry that is not in the list can be typed', (tester) async {
      final positions = _FakePositions();
      await _pump(tester, const LeadersScreen(), base(positions: positions));
      await tester.tap(find.byKey(const Key('request-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ministry-choice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other (type it below)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ministry-other')), 'Drama Team');
      await tester.enterText(find.byKey(const Key('ministry-title')), 'Coordinator');
      await tester.tap(find.byKey(const Key('send-position-request')));
      await tester.pumpAndSettle();
      expect(positions.requested.single,
          const MinistryPosition(ministry: 'Drama Team', title: 'Coordinator'));
    });

    testWidgets('a request needs a ministry and a position', (tester) async {
      final positions = _FakePositions();
      await _pump(tester, const LeadersScreen(), base(positions: positions));
      await tester.tap(find.byKey(const Key('request-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-position-request')));
      await tester.pumpAndSettle();
      expect(find.text('Choose the ministry'), findsOneWidget);
      expect(find.text('Enter the position'), findsOneWidget);
      expect(positions.requested, isEmpty);
    });

    testWidgets('a waiting request is shown instead of the button', (tester) async {
      await _pump(tester, const LeadersScreen(), base(pending: _choir));
      expect(find.byKey(const Key('request-position')), findsNothing);
      expect(find.byKey(const Key('position-pending')), findsOneWidget);
      expect(find.textContaining('Choir · Leader is waiting'), findsOneWidget);
    });
  });

  group('Ministry Reports (a leader)', () {
    List<Override> base(UserAccess access, _FakeReports repo,
            {List<MinistryReport> mine = const []}) =>
        [
          userRoleProvider.overrideWith((ref) => Stream.value(access)),
          ministryReportRepositoryProvider.overrideWithValue(repo),
          myMinistryReportsProvider.overrideWith((ref) => Stream.value(mine)),
          allMinistryReportsProvider.overrideWith((ref) => Stream.value(const [])),
        ];

    testWidgets('someone with no position is pointed to Leaders', (tester) async {
      await _pump(tester, const MinistryReportsScreen(),
          base(UserAccess.member, _FakeReports()));
      expect(find.textContaining('for ministry leaders and the Pastor'), findsOneWidget);
      expect(find.byKey(const Key('new-report')), findsNothing);
    });

    testWidgets('a leader with no reports is told how to start', (tester) async {
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir]), _FakeReports()));
      expect(find.textContaining('not sent a report yet'), findsOneWidget);
      expect(find.byKey(const Key('new-report')), findsOneWidget);
    });

    testWidgets('a leader sees their own reports with their status', (tester) async {
      await _pump(
          tester,
          const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir]), _FakeReports(), mine: [
            _report('a'),
            _report('b', summary: 'Visited the sick', reviewed: true),
          ]));
      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
      expect(find.textContaining('Visited the sick'), findsOneWidget);
    });

    testWidgets('a leader can write a report and send it to the Pastor', (tester) async {
      final repo = _FakeReports();
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir]), repo));
      await tester.tap(find.byKey(const Key('new-report')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-attendance')), '31');
      await tester.enterText(
          find.byKey(const Key('report-summary')), '  Practised two new songs.  ');
      await tester.enterText(find.byKey(const Key('report-needs')), 'Microphones');
      await tester.ensureVisible(find.byKey(const Key('send-report')));
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();

      final sent = repo.added.single;
      expect(sent.authorUid, 'u1');
      expect(sent.authorName, 'Ruth Banda');
      expect(sent.ministry, 'Choir');
      expect(sent.ministryKey, 'choir');
      expect(sent.position, 'Leader');
      expect(sent.attendance, 31);
      expect(sent.summary, 'Practised two new songs.'); // trimmed
      expect(sent.needs, 'Microphones');
      expect(sent.status, ReportStatus.sent);
      expect(find.text('Report sent to the Pastor.'), findsOneWidget);
      expect(find.byKey(const Key('send-report')), findsNothing); // back on the list
    });

    testWidgets('a report needs to say what happened', (tester) async {
      final repo = _FakeReports();
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir]), repo));
      await tester.tap(find.byKey(const Key('new-report')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('send-report')));
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(find.text('Tell the Pastor what happened'), findsOneWidget);
      expect(repo.added, isEmpty);
    });

    testWidgets('a leader of two ministries must choose which one', (tester) async {
      final repo = _FakeReports();
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir, _woi]), repo));
      await tester.tap(find.byKey(const Key('new-report')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-summary')), 'Met on Saturday');
      await tester.ensureVisible(find.byKey(const Key('send-report')));
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(find.text('Choose the ministry'), findsOneWidget);
      expect(repo.added, isEmpty);

      await tester.tap(find.byKey(const Key('report-ministry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Women of Integrity · Secretary').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('send-report')));
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(repo.added.single.ministryKey, 'women-of-integrity');
      expect(repo.added.single.position, 'Secretary');
    });

    testWidgets('a failed send says so and keeps what was written', (tester) async {
      final repo = _FakeReports()..failing = true;
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.member}, [_choir]), repo));
      await tester.tap(find.byKey(const Key('new-report')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-summary')), 'Important news');
      await tester.ensureVisible(find.byKey(const Key('send-report')));
      await tester.tap(find.byKey(const Key('send-report')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-error')), findsOneWidget);
      expect(find.text('Important news'), findsOneWidget);
    });
  });

  group('a report in detail', () {
    List<Override> base(UserAccess access, _FakeReports repo, MinistryReport r,
            {bool asAuthor = true}) =>
        [
          userRoleProvider.overrideWith((ref) => Stream.value(access)),
          ministryReportRepositoryProvider.overrideWithValue(repo),
          myMinistryReportsProvider
              .overrideWith((ref) => Stream.value(asAuthor ? [r] : const [])),
          allMinistryReportsProvider.overrideWith((ref) =>
              Stream.value(access.canReviewMinistryReports ? [r] : const [])),
          if (!asAuthor) currentUserIdProvider.overrideWithValue('someone-else'),
        ];

    testWidgets('the author can change or withdraw it until it is reviewed', (tester) async {
      final r = _report('a');
      await _pump(tester, MinistryReportDetailScreen(report: r),
          base(_access({UserRole.member}, [_choir]), _FakeReports(), r));
      expect(find.byTooltip('Change'), findsOneWidget);
      expect(find.byTooltip('Withdraw'), findsOneWidget);
      expect(find.byKey(const Key('mark-reviewed')), findsNothing);
      expect(find.text('Few sopranos'), findsOneWidget);
      expect(find.text('New hymn books'), findsOneWidget);
      expect(find.text('24 attended'), findsOneWidget);
    });

    testWidgets('withdrawing asks first', (tester) async {
      final repo = _FakeReports();
      final r = _report('a');
      await _pump(tester, MinistryReportDetailScreen(report: r),
          base(_access({UserRole.member}, [_choir]), repo, r));
      await tester.tap(find.byTooltip('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);

      await tester.tap(find.byTooltip('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['a']);
    });

    testWidgets('once reviewed it is locked, and the Pastor\'s reply shows', (tester) async {
      final r = _report('a', reviewed: true, note: 'Thank you, well done.');
      await _pump(tester, MinistryReportDetailScreen(report: r),
          base(_access({UserRole.member}, [_choir]), _FakeReports(), r));
      expect(find.byTooltip('Change'), findsNothing);
      expect(find.byTooltip('Withdraw'), findsNothing);
      expect(find.byKey(const Key('reviewed-line')), findsOneWidget);
      expect(find.textContaining('Reviewed by Pastor Mwale'), findsOneWidget);
      expect(find.byKey(const Key('pastor-note')), findsOneWidget);
      expect(find.text('Thank you, well done.'), findsOneWidget);
    });

    testWidgets('the Pastor can reply and mark it reviewed', (tester) async {
      final repo = _FakeReports();
      final r = _report('a', uid: 'u9', author: 'Grace Mulenga');
      await _pump(tester, MinistryReportDetailScreen(report: r),
          base(_access({UserRole.pastor}), repo, r, asAuthor: false));
      expect(find.byTooltip('Change'), findsNothing); // not theirs to change
      await tester.enterText(find.byKey(const Key('review-note')), '  Keep going  ');
      await tester.ensureVisible(find.byKey(const Key('mark-reviewed')));
      await tester.tap(find.byKey(const Key('mark-reviewed')));
      await tester.pumpAndSettle();
      final done = repo.reviewedWith.single;
      expect(done.id, 'a');
      expect(done.note, 'Keep going'); // trimmed
      expect(done.reviewer, 'Ruth Banda'); // the signed-in person's name
    });

    testWidgets('a reviewed report offers to update the reply instead', (tester) async {
      final r = _report('a', uid: 'u9', reviewed: true, note: 'Thanks');
      await _pump(tester, MinistryReportDetailScreen(report: r),
          base(_access({UserRole.pastor}), _FakeReports(), r, asAuthor: false));
      expect(find.text('Update reply'), findsOneWidget);
      expect(find.text('Mark as reviewed'), findsNothing);
    });
  });

  group('Ministry Reports (the Pastor)', () {
    List<Override> base(UserAccess access, List<MinistryReport> all) => [
          userRoleProvider.overrideWith((ref) => Stream.value(access)),
          ministryReportRepositoryProvider.overrideWithValue(_FakeReports()),
          myMinistryReportsProvider.overrideWith((ref) => Stream.value(const [])),
          allMinistryReportsProvider.overrideWith((ref) => Stream.value(all)),
        ];

    final all = [
      _report('a', uid: 'u1', author: 'Ruth Banda'),
      _report('b', uid: 'u2', author: 'Grace Mulenga', p: _woi, reviewed: true),
      _report('c', uid: 'u3', author: 'Joe Phiri', summary: 'Practice went well'),
    ];

    testWidgets('sees everyone\'s reports, who wrote them, and how many are waiting', (tester) async {
      await _pump(tester, const MinistryReportsScreen(), base(_access({UserRole.pastor}), all));
      expect(find.text('Ministry Reports'), findsOneWidget);
      expect(find.text('2 waiting to be reviewed'), findsOneWidget);
      expect(find.textContaining('Ruth Banda, Leader'), findsOneWidget);
      expect(find.textContaining('Grace Mulenga, Secretary'), findsOneWidget);
      expect(find.text('New'), findsNWidgets(3)); // two tags and the filter chip
      expect(find.byKey(const Key('new-report')), findsNothing);
    });

    testWidgets('can look at only the new ones, or only the reviewed ones', (tester) async {
      await _pump(tester, const MinistryReportsScreen(), base(_access({UserRole.pastor}), all));
      await tester.tap(find.byKey(const Key('filter-fresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-a')), findsOneWidget);
      expect(find.byKey(const Key('report-c')), findsOneWidget);
      expect(find.byKey(const Key('report-b')), findsNothing);

      await tester.tap(find.byKey(const Key('filter-reviewed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-b')), findsOneWidget);
      expect(find.byKey(const Key('report-a')), findsNothing);
    });

    testWidgets('says when everything has been reviewed', (tester) async {
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.pastor}), [_report('b', reviewed: true)]));
      expect(find.text('Everything has been reviewed.'), findsOneWidget);
    });

    testWidgets('says when no reports have come in', (tester) async {
      await _pump(tester, const MinistryReportsScreen(), base(_access({UserRole.pastor}), const []));
      expect(find.text('No reports have been sent yet.'), findsOneWidget);
    });

    testWidgets('a Pastor who also leads a ministry can write one too', (tester) async {
      await _pump(tester, const MinistryReportsScreen(),
          base(_access({UserRole.pastor}, [_choir]), all));
      expect(find.byKey(const Key('new-report')), findsOneWidget);
    });

    testWidgets('a report can be opened from the list', (tester) async {
      await _pump(tester, const MinistryReportsScreen(), base(_access({UserRole.admin}), all));
      await tester.tap(find.byKey(const Key('report-c')));
      await tester.pumpAndSettle();
      expect(find.byType(MinistryReportDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('mark-reviewed')), findsOneWidget);
    });
  });

  test('FieldValue is available for the directory entries', () {
    // The directory's `updatedAt` is a server timestamp; make sure building one in
    // a unit test does not need Firebase.
    expect(FieldValue.serverTimestamp(), isNotNull);
  });
}
