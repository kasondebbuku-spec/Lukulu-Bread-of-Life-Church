import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/notifications_provider.dart';
import 'package:church_cms/core/providers/user_profile_provider.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/dashboard/widgets/pending_role_banner.dart';
import 'package:church_cms/features/notifications/screens/notifications_screen.dart';
import 'package:church_cms/features/notifications/widgets/notification_bell.dart';
import 'package:church_cms/models/announcement.dart';
import 'package:church_cms/models/app_notification.dart';
import 'package:church_cms/models/church_event.dart';
import 'package:church_cms/repositories/repository_providers.dart';
import 'package:church_cms/services/notification_service.dart';

final _now = DateTime(2026, 10, 20, 12);

Announcement _announcement(String title, DateTime? at, {String by = 'Pastor'}) =>
    Announcement(
        id: title,
        title: title,
        content: 'body',
        createdBy: by,
        targetAudience: 'all',
        createdAt: at);

ChurchEvent _event(String title, DateTime? at) => ChurchEvent(
    id: title,
    title: title,
    date: DateTime(2026, 11, 1),
    location: 'Main Sanctuary',
    createdAt: at);

class _FakeNotificationService implements NotificationService {
  int marked = 0;

  @override
  Future<void> markAllSeen() async => marked++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('buildNotifications', () {
    test('merges announcements and events, newest first', () {
      final items = buildNotifications(
        announcements: [_announcement('Old', _now.subtract(const Duration(days: 5)))],
        events: [_event('Fresh', _now.subtract(const Duration(hours: 2)))],
        now: _now,
      );
      expect(items.map((n) => n.title), ['Fresh', 'Old']);
      expect(items.first.kind, NotificationKind.event);
      expect(items.first.detail, contains('Nov 1, 2026'));
      expect(items.first.detail, contains('Main Sanctuary'));
      expect(items.last.detail, 'Announcement from Pastor');
    });

    test('leaves out news older than 30 days and items still being saved', () {
      final items = buildNotifications(
        announcements: [
          _announcement('Ancient', _now.subtract(const Duration(days: 45))),
          _announcement('Saving', null),
        ],
        events: [_event('Saving event', null)],
        now: _now,
      );
      expect(items, isEmpty);
    });
  });

  group('unreadCount', () {
    final items = buildNotifications(
      announcements: [
        _announcement('A', _now.subtract(const Duration(days: 3))),
        _announcement('B', _now.subtract(const Duration(days: 1))),
      ],
      events: [_event('C', _now.subtract(const Duration(hours: 1)))],
      now: _now,
    );

    test('everything is new until the person first opens notifications', () {
      expect(unreadCount(items, null), 3);
    });

    test('only what was posted after they last looked counts', () {
      expect(unreadCount(items, _now.subtract(const Duration(days: 2))), 2);
      expect(unreadCount(items, _now), 0);
    });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    required List<Announcement> announcements,
    required List<ChurchEvent> events,
    DateTime? seenAt,
    _FakeNotificationService? service,
    Map<String, dynamic>? profile,
    UserAccess access = UserAccess.member,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        announcementsProvider.overrideWith((ref) => Stream.value(announcements)),
        eventsProvider.overrideWith((ref) => Stream.value(events)),
        userProfileProvider.overrideWith((ref) => Stream.value({
              if (seenAt != null) 'notificationsSeenAt': Timestamp.fromDate(seenAt),
              ...?profile,
            })),
        userRoleProvider.overrideWith((ref) => Stream.value(access)),
        notificationServiceProvider
            .overrideWithValue(service ?? _FakeNotificationService()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: home)),
    ));
    await tester.pumpAndSettle();
  }

  // Posted relative to the real clock, because the providers use DateTime.now().
  DateTime ago(Duration d) => DateTime.now().subtract(d);

  testWidgets('the bell shows how many new announcements and events there are',
      (tester) async {
    await pump(tester, const Center(child: NotificationBell()),
        announcements: [
          _announcement('A', ago(const Duration(days: 2))),
          _announcement('B', ago(const Duration(hours: 5))),
        ],
        events: [_event('C', ago(const Duration(hours: 1)))],
        seenAt: ago(const Duration(days: 1)));
    expect(find.text('2'), findsOneWidget); // B and C, not A
    expect(find.byTooltip('Notifications (2 new)'), findsOneWidget);
  });

  testWidgets('no badge when everything has been seen', (tester) async {
    await pump(tester, const Center(child: NotificationBell()),
        announcements: [_announcement('A', ago(const Duration(days: 2)))],
        events: const [],
        seenAt: ago(const Duration(hours: 1)));
    expect(find.byType(Badge), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(find.byTooltip('Notifications'), findsOneWidget);
  });

  testWidgets('opening notifications lists them, highlights new ones and marks seen',
      (tester) async {
    final service = _FakeNotificationService();
    await pump(tester, const NotificationsScreen(),
        announcements: [
          _announcement('Sunday service moved', ago(const Duration(hours: 3))),
          _announcement('Last month news', ago(const Duration(days: 10))),
        ],
        events: [_event('Youth retreat', ago(const Duration(hours: 1)))],
        seenAt: ago(const Duration(days: 2)),
        service: service);

    expect(find.text('Youth retreat'), findsOneWidget);
    expect(find.text('Sunday service moved'), findsOneWidget);
    expect(find.text('Last month news'), findsOneWidget);
    // two new ones carry the dot; the old one a chevron
    expect(find.byIcon(Icons.circle), findsNWidgets(2));
    expect(service.marked, 1);
  });

  testWidgets('an empty list says you are all caught up', (tester) async {
    await pump(tester, const NotificationsScreen(),
        announcements: const [], events: const []);
    expect(find.textContaining('all caught up'), findsOneWidget);
  });

  testWidgets('someone waiting on a role request is told so on Home',
      (tester) async {
    await pump(tester, const PendingRoleBanner(),
        announcements: const [],
        events: const [],
        profile: {'requestedRole': 'finance'});
    expect(find.text('Waiting for Admin approval'), findsOneWidget);
    expect(find.textContaining('You asked to be Finance Officer'), findsOneWidget);
  });

  testWidgets('no notice once the role has been approved', (tester) async {
    await pump(tester, const PendingRoleBanner(),
        announcements: const [],
        events: const [],
        profile: {'requestedRole': 'finance'},
        access: const UserAccess({UserRole.finance}));
    expect(find.text('Waiting for Admin approval'), findsNothing);
  });

  testWidgets('no notice for an ordinary member', (tester) async {
    await pump(tester, const PendingRoleBanner(),
        announcements: const [], events: const []);
    expect(find.text('Waiting for Admin approval'), findsNothing);
  });
}
