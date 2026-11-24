import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/navigation/app_shell.dart';
import 'package:church_cms/repositories/repository_providers.dart';

/// On a phone each of the five bottom-bar items has about 70px, so a long word
/// such as "Announcements" breaks mid-word ("Announcemen" / "ts"). Widget tests
/// use a fake wide font, so rather than measuring pixels this guards the cause:
/// every bar label must stay short.
const _longestBarLabel = 10; // "Attendance" is the longest that fits.

void main() {
  final roles = <String, UserAccess>{
    'member': UserAccess.member,
    'elder': const UserAccess({UserRole.elder}),
    'finance': const UserAccess({UserRole.finance}),
    'admin': const UserAccess({UserRole.admin}),
  };

  for (final entry in roles.entries) {
    testWidgets('${entry.key} bottom bar has only short labels', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userRoleProvider.overrideWith((ref) => Stream.value(entry.value)),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          eventsProvider.overrideWith((ref) => Stream.value([])),
          announcementsProvider.overrideWith((ref) => Stream.value([])),
          prayerRequestsProvider.overrideWith((ref) => Stream.value([])),
          incomeFormsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AppShell()),
      ));
      await tester.pumpAndSettle();

      final labels = find
          .descendant(of: find.byType(NavigationBar), matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .toList();
      expect(labels, isNotEmpty);
      for (final label in labels) {
        expect(label.length, lessThanOrEqualTo(_longestBarLabel),
            reason: '"$label" is too long for the phone bottom bar');
      }
      expect(labels, isNot(contains('Announcements')));
    });
  }

  testWidgets('a member sees Notices in the bar but the full word elsewhere',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userRoleProvider.overrideWith((ref) => Stream.value(UserAccess.member)),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        eventsProvider.overrideWith((ref) => Stream.value([])),
        announcementsProvider.overrideWith((ref) => Stream.value([])),
        prayerRequestsProvider.overrideWith((ref) => Stream.value([])),
        incomeFormsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AppShell()),
    ));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Notices')),
        findsOneWidget);

    // On a wide screen the sidebar has room for the full word.
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text('Notices'), findsNothing);
    expect(find.text('Announcements'), findsWidgets);
  });
}
