import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/giving_screen.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  testWidgets('Oversight can inspect income without mutation controls', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      userRoleProvider.overrideWith((ref) => Stream.value(const UserAccess({UserRole.oversight}))),
      givingRecordsProvider.overrideWith((ref) => Stream.value([
        GivingRecord(id: 'sample', memberName: 'Sample Member', amount: 100,
          date: DateTime.now(), category: GivingCategory.tithe),
      ])),
    ], child: MaterialApp(theme: AppTheme.lightTheme, home: const GivingScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Sample Member'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.link), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
