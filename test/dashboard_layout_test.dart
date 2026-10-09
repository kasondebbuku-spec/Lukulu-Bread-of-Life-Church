import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/models/church_event.dart';
import 'package:church_cms/navigation/app_shell.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final soon = ChurchEvent(
      id: '1',
      title: 'Sunday Worship Service',
      date: DateTime.now().add(const Duration(days: 2)),
      location: 'Main Sanctuary',
    );
    await tester.pumpWidget(ProviderScope(overrides: [
      userRoleProvider.overrideWith(
          (ref) => Stream.value(const UserAccess({UserRole.admin}))),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      membersProvider.overrideWith((ref) => Stream.value([])),
      givingRecordsProvider.overrideWith((ref) => Stream.value([])),
      attendanceRecordsProvider.overrideWith((ref) => Stream.value([])),
      eventsProvider.overrideWith((ref) => Stream.value([soon])),
      announcementsProvider.overrideWith((ref) => Stream.value([])),
      prayerRequestsProvider.overrideWith((ref) => Stream.value([])),
    ], child: MaterialApp(theme: AppTheme.lightTheme, home: const AppShell())));
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(1440, 900), // desktop: sidebar + three-column cards
    Size(1000, 600), // short laptop
    Size(390, 800), // phone: bottom bar, stacked cards
  ]) {
    testWidgets('dashboard lays out without overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpShell(tester, size);
      expect(find.text('Upcoming Events'), findsOneWidget);
      expect(find.text('Quick Access'), findsOneWidget);
      expect(find.text('Daily Verse'), findsOneWidget);
      expect(find.text('Sunday Worship Service'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
