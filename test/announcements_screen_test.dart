import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/announcements/screens/announcements_screen.dart';
import 'package:church_cms/models/announcement.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<Announcement> items) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        announcementsProvider.overrideWith((ref) => Stream.value(items)),
        userRoleProvider.overrideWith(
            (ref) => Stream.value(const UserAccess({UserRole.admin}))),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme, home: const AnnouncementsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the writing box is roomy, multi-line and has a length limit',
      (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final content = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Content'));
    expect(content.minLines, greaterThanOrEqualTo(6));
    expect(content.maxLines, greaterThan(content.minLines!));
    expect(content.maxLength, announcementMaxLength);
    expect(content.keyboardType, TextInputType.multiline);

    final box = tester.getSize(find.widgetWithText(TextField, 'Content'));
    expect(box.height, greaterThan(150), reason: 'was a cramped 3-line box');
    expect(box.width, greaterThan(400));
  });

  testWidgets('a long announcement is shown in full, not cut off',
      (tester) async {
    final longText = List.generate(40, (i) => 'Line number $i of the notice.').join('\n');
    await pump(tester, [
      Announcement(
          id: 'a1',
          title: 'Big notice',
          content: longText,
          createdBy: 'Admin',
          targetAudience: 'all'),
    ]);
    expect(find.textContaining('Line number 39 of the notice.'), findsOneWidget);
    expect(find.textContaining('Line number 0 of the notice.'), findsOneWidget);
  });
}
