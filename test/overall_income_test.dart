import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';
import 'package:church_cms/features/giving/widgets/overall_income_card.dart';
import 'package:church_cms/features/giving/zmw_denominations.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';

const _title = 'Sunday Service Overall Income (all categories combined)';

Future<void> _bigScreen(WidgetTester tester) async {
  // Tall enough that the whole (lazy) form list is built.
  tester.view.physicalSize = const Size(900, 14000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('the combined income card', () {
    testWidgets('lists each note once, with its combined count and amount',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: OverallIncomeCard(counts: {'500': 5, '200': 2, '0.5': 3}),
        ),
      ));
      expect(find.text(_title), findsOneWidget);
      expect(find.text('K500'), findsOneWidget);
      expect(find.text('x 5'), findsOneWidget);
      expect(find.text('ZMW 2500.00'), findsOneWidget);
      expect(find.text('K200'), findsOneWidget);
      expect(find.text('ZMW 400.00'), findsOneWidget);
      expect(find.text('50 ngwee'), findsOneWidget);
      expect(find.text('ZMW 1.50'), findsOneWidget);
      // 2500 + 400 + 1.50
      expect(find.text('Overall cash total'), findsOneWidget);
      expect(find.text('ZMW 2901.50'), findsOneWidget);
      // Notes that were not counted are not listed.
      expect(find.text('K100'), findsNothing);
    });

    testWidgets('says so when nothing has been counted', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: OverallIncomeCard(counts: {})),
      ));
      expect(find.text('No cash counted yet.'), findsOneWidget);
      expect(find.text('ZMW 0.00'), findsOneWidget);
    });

    testWidgets('has no explanatory sentence, only the title and the figures',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: OverallIncomeCard(counts: {'100': 1})),
      ));
      expect(find.textContaining('whichever'), findsNothing);
      expect(find.textContaining('regardless'), findsNothing);
    });
  });

  testWidgets('on the form, the K500s from tithe and offering add up together',
      (tester) async {
    await _bigScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme, home: const SundayIncomeFormScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No cash counted yet.'), findsOneWidget);

    // Each category table has one field per note, in the same order, and
    // the tables run Tithe, Offering, Seed, Thanksgiving, Pledge. So field 0 is
    // the tithe K500 and field N (the number of denominations) is the offering K500.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2'); // tithe K500
    await tester.enterText(fields.at(zmwDenominations.length), '3'); // offering K500
    await tester.pumpAndSettle();

    expect(find.text('No cash counted yet.'), findsNothing);
    expect(find.text('x 5'), findsOneWidget); // 2 + 3
    expect(find.text('ZMW 2500.00'), findsWidgets);
  });

  testWidgets('on a saved form, the notes from every category are combined',
      (tester) async {
    await _bigScreen(tester);
    final form = SundayIncomeForm(
      id: 'abc',
      date: DateTime(2026, 11, 22),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: CategoryBlock(
              denominationBreakdown: switch (c) {
            GivingCategory.tithe => const {'100': 29},
            GivingCategory.offering => const {'100': 3, '50': 2},
            _ => const {},
          }),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 1,
      women: 1,
      children: 1,
      preparedBy: 'a',
      checkedBy: 'b',
      collectedBy: 'c',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userRoleProvider
            .overrideWith((ref) => Stream.value(const UserAccess({UserRole.finance}))),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme, home: IncomeFormDetailScreen(form: form)),
    ));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.text('x 32'), findsOneWidget); // 29 + 3 K100 notes
    expect(find.text('ZMW 3200.00'), findsWidgets);
    expect(find.text('x 2'), findsOneWidget); // two K50
    // 3200 + 100
    expect(find.text('ZMW 3300.00'), findsWidgets);
  });
}
