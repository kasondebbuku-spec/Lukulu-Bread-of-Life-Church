import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) async {
    // Tall enough that the whole (lazy) form list is built.
    tester.view.physicalSize = const Size(900, 14000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme, home: const SundayIncomeFormScreen()),
    ));
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder.first).dy;

  testWidgets('the Tithe of Tithes and Natsave lines come after the expenses',
      (tester) async {
    await pumpForm(tester);

    final expenses = find.text('Expenses');
    final titheOfTithes = find.textContaining('Tithe of Tithes (10% of tithe):');
    final natsave = find.textContaining('Natsave Deposit: ZMW');
    final attendance = find.text('Attendance');

    expect(expenses, findsOneWidget);
    expect(titheOfTithes, findsOneWidget);
    expect(natsave, findsOneWidget);

    // Order down the page: the expenses list, then the worked-out lines, then
    // attendance.
    expect(top(tester, titheOfTithes), greaterThan(top(tester, expenses)));
    expect(top(tester, natsave), greaterThan(top(tester, titheOfTithes)));
    expect(top(tester, attendance), greaterThan(top(tester, natsave)));
  });

  testWidgets('the worked-out lines carry no explanatory sentences',
      (tester) async {
    await pumpForm(tester);
    expect(find.textContaining('Worked out for you'), findsNothing);
    expect(find.textContaining('It is not an expense'), findsNothing);
    expect(find.textContaining('The rest, after'), findsNothing);
    expect(find.textContaining('goes into the Natsave account'), findsNothing);
  });

  testWidgets('there are no cash counts for Natsave, the tithe of tithes or the expenses',
      (tester) async {
    await pumpForm(tester);
    expect(find.text('Natsave Account Deposit'), findsNothing);
    expect(find.textContaining('Tithe of Tithes Cash Count'), findsNothing);
    // Expenses are only listed (a description and an amount each).
    expect(find.text('Expenses Cash Count'), findsNothing);
    expect(find.text('Expenses'), findsOneWidget);
  });

  testWidgets('the totals name the tithe of tithes with its 10% in brackets',
      (tester) async {
    await pumpForm(tester);
    // One on the worked-out card, one in the live totals.
    expect(find.textContaining('Tithe of Tithes (10% of tithe)'), findsNWidgets(2));
    expect(find.text('Net Amount'), findsOneWidget);
  });
}
