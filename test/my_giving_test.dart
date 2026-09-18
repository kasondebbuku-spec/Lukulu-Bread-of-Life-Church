import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/my_giving_screen.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  testWidgets('Personal history keeps currencies separate and filters tithes',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myGivingProvider.overrideWith((ref) => Stream.value([
                GivingRecord(
                    id: 'tithe-ref',
                    memberName: 'Member',
                    amount: 100,
                    date: DateTime(2026, 9, 1),
                    category: GivingCategory.tithe),
                GivingRecord(
                    id: 'offering-ref',
                    memberName: 'Member',
                    amount: 20,
                    currency: 'USD',
                    date: DateTime(2026, 9, 2),
                    category: GivingCategory.offering),
              ])),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: const MyGivingScreen())));
    await tester.pumpAndSettle();
    expect(find.text('ZMW 100.00 • Selected total'), findsOneWidget);
    expect(find.text('USD 20.00 • Selected total'), findsOneWidget);
    await tester.tap(find.text('Tithes only'));
    await tester.pumpAndSettle();
    expect(find.text('USD 20.00 • Selected total'), findsNothing);
    expect(find.text('ZMW 100.00 • Selected total'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Errors are not displayed as zero giving', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myGivingProvider
              .overrideWith((ref) => Stream.error(StateError('offline'))),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: const MyGivingScreen())));
    await tester.pumpAndSettle();
    expect(
        find.text('Your giving history could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Selected total'), findsNothing);
  });
}
