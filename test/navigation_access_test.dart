import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/navigation/app_shell.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  testWidgets(
      'Admin navigation fits short desktop screens and includes private giving',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      userRoleProvider.overrideWith(
          (ref) => Stream.value(const UserAccess({UserRole.admin}))),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      membersProvider.overrideWith((ref) => Stream.value([])),
      givingRecordsProvider.overrideWith((ref) => Stream.value([])),
      attendanceRecordsProvider.overrideWith((ref) => Stream.value([])),
      eventsProvider.overrideWith((ref) => Stream.value([])),
      announcementsProvider.overrideWith((ref) => Stream.value([])),
      prayerRequestsProvider.overrideWith((ref) => Stream.value([])),
    ], child: MaterialApp(theme: AppTheme.lightTheme, home: const AppShell())));
    await tester.pumpAndSettle();
    expect(find.text('My Giving'), findsOneWidget);
    expect(find.text('Account Roles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
