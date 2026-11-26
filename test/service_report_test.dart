import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/current_user_provider.dart';
import 'package:church_cms/core/providers/display_name_provider.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/service_report_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/service_report/pdf/service_report_pdf.dart';
import 'package:church_cms/features/service_report/screens/service_report_detail_screen.dart';
import 'package:church_cms/features/service_report/screens/service_report_form_screen.dart';
import 'package:church_cms/features/service_report/screens/service_report_list_screen.dart';
import 'package:church_cms/features/service_report/widgets/service_report_home_card.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/service_report.dart';
import 'package:church_cms/repositories/service_report_repository.dart';

final _today = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}();

ServiceReport _full({String id = 'r1', DateTime? date}) => ServiceReport(
      id: id,
      date: date ?? DateTime(2026, 11, 22),
      openingPrayerBy: 'Elder Banda',
      intercessionBy: 'Mrs. Zulu',
      praisesBy: 'Choir',
      worshipBy: 'Ruth',
      leadersOnDuty: const ['Peter', 'Mary'],
      announcementsBy: 'Maureen',
      exhortationBy: 'Deacon Mabai',
      exhortationTitle: 'Give thanks',
      exhortationReading: 'Psalm 100',
      preacher: 'Pastor Mwale',
      wordTitle: 'Faith that works',
      wordReading: 'James 2:14-26',
      wordSummary: 'Faith shows itself in what we do.',
      testimonies: const [Testimony(name: 'Joseph', summary: 'Healed after prayer.')],
      closingPrayerBy: 'Elder Banda',
      men: 21,
      women: 34,
      children: 18,
      collections: const {
        GivingCategory.tithe: 800,
        GivingCategory.offering: 1479,
        GivingCategory.seed: 50,
      },
      noticesBy: 'Maureen',
      visitors: const [Visitor(name: 'John Phiri', origin: 'Mongu')],
      notices: const ['Baby girl born to the Mwansa family'],
      specialOffering: const ['Honoured pledge: Mrs. Tembo'],
      nextWeekLeaders: const ['Elder Phiri', 'Deaconess Lungu'],
      secretaryName: 'Maureen Mwaba',
      treasurerName: 'Mike Mabai',
      elderName: 'Elder Banda',
      enteredBy: 'Maureen Mwaba',
      enteredByUid: 'u1',
    );

class _FakeRepo implements ServiceReportRepository {
  final added = <ServiceReport>[];
  final updated = <({String id, ServiceReport report})>[];
  final deleted = <String>[];
  bool failing = false;

  @override
  Future<void> add(ServiceReport item) async {
    if (failing) throw StateError('offline');
    added.add(item);
  }

  @override
  Future<void> update(String id, ServiceReport report) async =>
      updated.add((id: id, report: report));

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserAccess _as(UserRole r) => UserAccess({r});

Future<_FakeRepo> _pump(
  WidgetTester tester,
  Widget home, {
  UserRole role = UserRole.secretariat,
  List<ServiceReport> saved = const [],
  _FakeRepo? repo,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final r = repo ?? _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userRoleProvider.overrideWith((ref) => Stream.value(_as(role))),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('u1'),
      displayNameProvider.overrideWithValue('Maureen Mwaba'),
      serviceReportRepositoryProvider.overrideWithValue(r),
      serviceReportsProvider.overrideWith((ref) => Stream.value(saved)),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
  return r;
}

/// Opens [screen] on top of a plain page, so leaving it can be tested.
class _Opener extends StatelessWidget {
  const _Opener(this.screen);
  final Widget screen;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      );
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('who may see and fill in the report', () {
    test('the Secretariat and Admin fill it in', () {
      final writers = UserRole.values.where((r) => r.canWriteServiceReports).toSet();
      expect(writers, {UserRole.secretariat, UserRole.admin});
    });

    test('the Pastor, Finance and Oversight can also see it, and no one else', () {
      final viewers = UserRole.values.where((r) => r.canViewServiceReports).toSet();
      expect(viewers, {
        UserRole.secretariat,
        UserRole.admin,
        UserRole.pastor,
        UserRole.finance,
        UserRole.oversight,
      });
    });
  });

  group('the report itself', () {
    test('adds up attendance and collections', () {
      final r = _full();
      expect(r.attendanceTotal, 73);
      expect(r.collectionsTotal, 2329);
      expect(ServiceReport(date: _today).attendanceTotal, 0);
      expect(ServiceReport(date: _today).collectionsTotal, 0);
    });

    test('is read back as it was saved', () {
      final original = _full();
      final back = ServiceReport.fromMap('r1', original.toContentMap()
        ..['enteredBy'] = original.enteredBy
        ..['enteredByUid'] = original.enteredByUid);
      expect(back.date, original.date);
      expect(back.serviceType, ServiceType.routine);
      expect(back.preacher, 'Pastor Mwale');
      expect(back.leadersOnDuty, ['Peter', 'Mary']);
      expect(back.testimonies.single.name, 'Joseph');
      expect(back.visitors.single.origin, 'Mongu');
      expect(back.collections[GivingCategory.offering], 1479);
      expect(back.collections.containsKey(GivingCategory.pledge), isFalse);
      expect(back.attendanceTotal, 73);
      expect(back.nextWeekLeaders, ['Elder Phiri', 'Deaconess Lungu']);
      expect(back.enteredBy, 'Maureen Mwaba');
    });

    test('keeps signatures, and leaves out ones that were never drawn', () {
      final signed = ServiceReport(
          date: _today, secretarySignature: Uint8List.fromList([1, 2, 3]));
      final map = signed.toContentMap();
      expect(map['secretarySignature'], 'AQID');
      expect(map.containsKey('treasurerSignature'), isFalse);
      expect(ServiceReport.fromMap('x', map).secretarySignature, [1, 2, 3]);
    });

    test('a damaged or empty record still opens', () {
      final r = ServiceReport.fromMap('x', {
        'serviceType': 'nonsense',
        'leadersOnDuty': [1, 'Peter', null],
        'collections': 'not a map',
        'testimonies': ['bad'],
        'men': 'many',
      });
      expect(r.serviceType, ServiceType.routine);
      expect(r.leadersOnDuty, ['Peter']);
      expect(r.collections, isEmpty);
      expect(r.men, 0);
      expect(r.testimonies.single.isEmpty, isTrue);
    });

    test('lists collections in the order of the paper form', () {
      expect(serviceCollectionOrder.map(serviceCollectionLabel),
          ['Pledges', 'Thanks Giving', 'Seed', 'Offering', 'Tithe']);
      expect(serviceCollectionOrder.toSet(), GivingCategory.values.toSet());
    });
  });

  group('the printed copy', () {
    test('is a PDF for a full report, with a name for the file', () async {
      final bytes = await buildServiceReportPdf(_full());
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(serviceReportPdfFilename(_full()), 'service-report-2026-11-22-routine.pdf');
    });

    test('can print a blank form to fill in by hand', () async {
      final bytes = await buildServiceReportPdf(null);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(serviceReportPdfFilename(null), 'service-report-blank.pdf');
    });

    test('copes with a very long message and testimony and many rows', () async {
      final long = ServiceReport(
        date: _today,
        wordSummary: 'The preacher said many good things. ' * 160, // ~5,700 letters
        testimonies: [
          for (var i = 0; i < 4; i++)
            Testimony(name: 'Person $i', summary: 'A long testimony. ' * 110),
        ],
        notices: [for (var i = 0; i < 30; i++) 'Notification number $i ${'x' * 150}'],
        visitors: [for (var i = 0; i < 30; i++) Visitor(name: 'V$i', origin: 'Mongu')],
      );
      final bytes = await buildServiceReportPdf(long);
      expect(bytes.length, greaterThan(1000));
    });

    test('turns phone-keyboard punctuation into plain letters', () {
      expect(pdfSafe('God’s “grace” – amen…'),
          'God\'s "grace" - amen...');
      expect(pdfSafe('Café · Mrs. Zulu\nnext'), 'Café · Mrs. Zulu\nnext');
      expect(pdfSafe('Praise 🙏'), 'Praise ?');
    });

    test('does not fail on such text', () async {
      final bytes = await buildServiceReportPdf(ServiceReport(
          date: _today,
          wordSummary: 'He’s risen — Hallelujah 🙌',
          notices: const ['“Baby” born']));
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('filling it in', () {
    testWidgets('follows the paper form from top to bottom', (tester) async {
      await _pump(tester, const ServiceReportFormScreen());
      for (final heading in [
        'Programme',
        'Exhortation',
        'Main Word',
        'Testimonies',
        'Attendance',
        'Collections',
        'Announcements',
        'Signatures',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      expect(y('sr-openingPrayerBy'), lessThan(y('sr-preacher')));
      expect(y('sr-preacher'), lessThan(y('sr-men')));
      expect(y('sr-men'), lessThan(y('sr-money-pledge')));
      expect(y('sr-money-tithe'), lessThan(y('sr-noticesBy')));
      expect(y('sr-noticesBy'), lessThan(y('sr-secretaryName')));
    });

    testWidgets('the Secretary\'s name is filled in for them', (tester) async {
      await _pump(tester, const ServiceReportFormScreen());
      final field = tester.widget<TextFormField>(find.byKey(const Key('sr-secretaryName')));
      expect(field.controller!.text, 'Maureen Mwaba');
    });

    testWidgets('an Admin\'s name is not put in the Secretary box', (tester) async {
      await _pump(tester, const ServiceReportFormScreen(), role: UserRole.admin);
      final field = tester.widget<TextFormField>(find.byKey(const Key('sr-secretaryName')));
      expect(field.controller!.text, '');
    });

    testWidgets('totals are worked out as the numbers are typed', (tester) async {
      await _pump(tester, const ServiceReportFormScreen());
      await _type(tester, 'sr-men', '10');
      await _type(tester, 'sr-women', '15');
      await _type(tester, 'sr-children', '5');
      expect(find.text('Total: 30'), findsOneWidget);
      await _type(tester, 'sr-money-tithe', '800');
      await _type(tester, 'sr-money-offering', '149.50');
      expect(find.text('Total: ZMW 949.50'), findsOneWidget);
    });

    testWidgets('saves what was typed, tidied, with who entered it', (tester) async {
      final repo = await _pump(tester, const _Opener(ServiceReportFormScreen()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _type(tester, 'sr-openingPrayerBy', '  Elder Banda ');
      await _type(tester, 'sr-preacher', 'Pastor Mwale');
      await _type(tester, 'sr-wordSummary', 'Faith shows itself.');
      await _type(tester, 'sr-duty-0', 'Peter');
      await _type(tester, 'sr-testimony-0', 'Joseph');
      await _type(tester, 'sr-testimony-b-0', 'Healed after prayer.');
      await _type(tester, 'sr-men', '20');
      await _type(tester, 'sr-money-seed', '50');
      await _type(tester, 'sr-visitor-0', 'John Phiri');
      await _type(tester, 'sr-visitor-b-0', 'Mongu');
      await _type(tester, 'sr-notice-1', 'Baby born to the Mwansa family');
      await _type(tester, 'sr-nextweek-0', 'Elder Phiri');
      await _tap(tester, 'sr-save');

      final saved = repo.added.single;
      expect(saved.date, _today);
      expect(saved.serviceType, ServiceType.routine);
      expect(saved.openingPrayerBy, 'Elder Banda');
      expect(saved.leadersOnDuty, ['Peter']); // the empty second line is left out
      expect(saved.testimonies.single.summary, 'Healed after prayer.');
      expect(saved.men, 20);
      expect(saved.collections, {GivingCategory.seed: 50.0});
      expect(saved.visitors.single.origin, 'Mongu');
      expect(saved.notices, ['Baby born to the Mwansa family']);
      expect(saved.nextWeekLeaders, ['Elder Phiri']);
      expect(saved.secretaryName, 'Maureen Mwaba');
      expect(saved.enteredBy, 'Maureen Mwaba');
      expect(saved.enteredByUid, 'u1');
      expect(find.text('Saved. You can find it again under Service Reports.'), findsOneWidget);
      expect(find.byType(ServiceReportFormScreen), findsNothing);
    });

    testWidgets('can be saved part-way and finished later', (tester) async {
      final repo = await _pump(tester, const ServiceReportFormScreen());
      await _tap(tester, 'sr-save');
      expect(repo.added, hasLength(1));
    });

    testWidgets('a special service is recorded as special', (tester) async {
      final repo = await _pump(tester, const ServiceReportFormScreen());
      await tester.tap(find.text('Special service'));
      await tester.pumpAndSettle();
      await _tap(tester, 'sr-save');
      expect(repo.added.single.serviceType, ServiceType.special);
    });

    testWidgets('lines can be added and removed', (tester) async {
      await _pump(tester, const ServiceReportFormScreen());
      expect(find.byKey(const Key('sr-notice-3')), findsNothing);
      await _tap(tester, 'sr-add-notice');
      expect(find.byKey(const Key('sr-notice-3')), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove line 4'));
      await tester.tap(find.byTooltip('Remove line 4'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sr-notice-3')), findsNothing);
    });

    testWidgets('a wrong amount stops the save and says so', (tester) async {
      final repo = await _pump(tester, const ServiceReportFormScreen());
      await _type(tester, 'sr-money-tithe', 'eight hundred');
      await _tap(tester, 'sr-save');
      expect(repo.added, isEmpty);
      expect(find.text('Enter an amount, e.g. 250'), findsOneWidget);
      expect(find.textContaining('Not saved yet'), findsOneWidget);
    });

    testWidgets('a failed save keeps everything typed and says nothing was saved', (tester) async {
      await _pump(tester, const ServiceReportFormScreen(), repo: _FakeRepo()..failing = true);
      await _type(tester, 'sr-preacher', 'Pastor Mwale');
      await _tap(tester, 'sr-save');
      expect(find.textContaining('Nothing was saved'), findsOneWidget);
      expect(find.text('Pastor Mwale'), findsOneWidget);
    });

    testWidgets('warns before saving a second report for the same service', (tester) async {
      final repo = await _pump(tester, const ServiceReportFormScreen(),
          saved: [_full(date: _today)]);
      await _tap(tester, 'sr-save');
      expect(find.text('There is already a report'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.added, isEmpty);

      await _tap(tester, 'sr-save');
      await tester.tap(find.text('Save anyway'));
      await tester.pumpAndSettle();
      expect(repo.added, hasLength(1));
    });

    testWidgets('a report for another day does not warn', (tester) async {
      final repo = await _pump(tester, const ServiceReportFormScreen(),
          saved: [_full(date: DateTime(2020, 1, 5))]);
      await _tap(tester, 'sr-save');
      expect(find.text('There is already a report'), findsNothing);
      expect(repo.added, hasLength(1));
    });

    testWidgets('leaving with typing unsaved asks first', (tester) async {
      await _pump(tester, const _Opener(ServiceReportFormScreen()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _type(tester, 'sr-preacher', 'Pastor Mwale');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep filling in'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceReportFormScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceReportFormScreen), findsNothing);
    });

    testWidgets('leaving an untouched form does not ask', (tester) async {
      await _pump(tester, const _Opener(ServiceReportFormScreen()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsNothing);
      expect(find.byType(ServiceReportFormScreen), findsNothing);
    });

    testWidgets('correcting a report keeps who first entered it', (tester) async {
      final repo = await _pump(
          tester, ServiceReportFormScreen(existing: _full()),
          role: UserRole.admin);
      await _type(tester, 'sr-men', '25');
      await _tap(tester, 'sr-save');
      final change = repo.updated.single;
      expect(change.id, 'r1');
      expect(change.report.men, 25);
      expect(change.report.preacher, 'Pastor Mwale'); // untouched fields stay
      expect(change.report.testimonies.single.name, 'Joseph');
      expect(change.report.enteredBy, 'Maureen Mwaba');
      expect(repo.added, isEmpty);
    });

    testWidgets('someone who may not fill it in is turned away', (tester) async {
      await _pump(tester, const ServiceReportFormScreen(), role: UserRole.pastor);
      expect(find.textContaining('Only the Secretariat and Admin'), findsOneWidget);
      expect(find.byKey(const Key('sr-save')), findsNothing);
    });
  });

  group('the list of reports', () {
    testWidgets('shows saved reports, with the preacher, attendance and who entered', (tester) async {
      await _pump(tester, const ServiceReportListScreen(), saved: [_full()]);
      expect(find.textContaining('Routine'), findsOneWidget);
      expect(find.textContaining('Preacher: Pastor Mwale'), findsOneWidget);
      expect(find.textContaining('Attendance: 73'), findsOneWidget);
      expect(find.textContaining('Entered by Maureen Mwaba'), findsOneWidget);
      expect(find.byKey(const Key('new-service-report')), findsOneWidget);
      expect(find.byKey(const Key('print-blank')), findsOneWidget);
    });

    testWidgets('says how to start when there are none', (tester) async {
      await _pump(tester, const ServiceReportListScreen());
      expect(find.textContaining('Tap Fill in report'), findsOneWidget);
    });

    for (final role in [UserRole.pastor, UserRole.finance, UserRole.oversight]) {
      testWidgets('${role.name} can look but not fill in', (tester) async {
        await _pump(tester, const ServiceReportListScreen(), role: role, saved: [_full()]);
        expect(find.byKey(const Key('service-report-r1')), findsOneWidget);
        expect(find.byKey(const Key('new-service-report')), findsNothing);
      });
    }

    for (final role in [UserRole.member, UserRole.elder, UserRole.deacon, UserRole.hospitality]) {
      testWidgets('${role.name} cannot see them', (tester) async {
        await _pump(tester, const ServiceReportListScreen(), role: role, saved: [_full()]);
        expect(find.textContaining('do not have access'), findsOneWidget);
        expect(find.byKey(const Key('service-report-r1')), findsNothing);
      });
    }
  });

  group('a saved report', () {
    testWidgets('reads like the paper form, with totals', (tester) async {
      await _pump(tester, ServiceReportDetailScreen(report: _full()), saved: [_full()]);
      expect(find.textContaining('Routine service'), findsOneWidget);
      expect(find.textContaining('Faith that works'), findsOneWidget);
      expect(find.textContaining('Men 21'), findsOneWidget);
      expect(find.text('Total ZMW 2329.00'), findsOneWidget);
      expect(find.text('1. John Phiri - Mongu'), findsOneWidget);
      expect(find.text('1. Baby girl born to the Mwansa family'), findsOneWidget);
      expect(find.text('Secretary: Maureen Mwaba'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byTooltip('Download PDF'), findsOneWidget);
    });

    testWidgets('the Secretariat can correct but not delete it', (tester) async {
      await _pump(tester, ServiceReportDetailScreen(report: _full()));
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('the Pastor can only read and print it', (tester) async {
      await _pump(tester, ServiceReportDetailScreen(report: _full()), role: UserRole.pastor);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.byTooltip('Print'), findsOneWidget);
    });

    testWidgets('the Admin can delete it, after being asked', (tester) async {
      final repo = await _pump(tester, ServiceReportDetailScreen(report: _full()),
          role: UserRole.admin);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['r1']);
    });
  });

  group('on the Home screen', () {
    Widget home() => const Scaffold(body: SingleChildScrollView(child: ServiceReportHomeCard()));

    testWidgets('the Secretariat has the report one tap away', (tester) async {
      await _pump(tester, home());
      expect(find.byKey(const Key('home-service-report')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-fill-report')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceReportFormScreen), findsOneWidget);
    });

    testWidgets('it says when the last one was saved and by whom', (tester) async {
      await _pump(tester, home(), saved: [_full()]);
      expect(find.textContaining('Last saved:'), findsOneWidget);
      expect(find.textContaining('by Maureen Mwaba'), findsOneWidget);
    });

    testWidgets('past reports are one tap away too', (tester) async {
      await _pump(tester, home(), saved: [_full()]);
      await tester.tap(find.byKey(const Key('home-past-reports')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceReportListScreen), findsOneWidget);
    });

    for (final role in [UserRole.member, UserRole.pastor, UserRole.finance, UserRole.elder]) {
      testWidgets('${role.name} has no fill-in card', (tester) async {
        await _pump(tester, home(), role: role);
        expect(find.byKey(const Key('home-service-report')), findsNothing);
      });
    }
  });
}
