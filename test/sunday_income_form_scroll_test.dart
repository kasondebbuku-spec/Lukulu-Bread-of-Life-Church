import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/sunday_income_form_screen.dart';

void main() {
  testWidgets('form scrolls normally and pauses scrolling only while signing',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
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

    final listFinder = find.byType(Scrollable).first;
    double offset() => tester.state<ScrollableState>(listFinder).position.pixels;

    expect(offset(), 0);
    await tester.drag(listFinder, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0), reason: 'form must scroll by dragging');

    // Jump to the bottom where the signature pads are.
    final position = tester.state<ScrollableState>(listFinder).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byType(Signature), findsNWidgets(3));

    // Pressing on a pad locks scrolling; releasing unlocks it.
    final pad = find.byType(Signature).first;
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    final lockedAt = offset();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(offset(), lockedAt, reason: 'drawing must not scroll the page');
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.drag(listFinder, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(offset(), lessThan(lockedAt), reason: 'scrolling works again after signing');
  });
}
