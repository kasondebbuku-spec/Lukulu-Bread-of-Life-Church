import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/firebase_providers.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/pdf/income_form_pdf.dart';
import 'package:church_cms/features/giving/screens/income_form_detail_screen.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';

SundayIncomeForm _form({ServiceType service = ServiceType.morning}) =>
    SundayIncomeForm(
      id: 'abc',
      date: DateTime(2026, 10, 4),
      service: service,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: const CategoryBlock(denominationBreakdown: {}),
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

void main() {
  test('PDF filename is dated and names the service', () {
    expect(incomeFormPdfFilename(_form()), 'income-form-2026-10-04-morning.pdf');
    expect(incomeFormPdfFilename(_form(service: ServiceType.evening)),
        'income-form-2026-10-04-evening.pdf');
  });

  test('PDF source only uses characters the built-in PDF font can draw', () {
    // Helvetica has no Unicode glyphs, so a stray em dash or similar prints as
    // a blank/missing character.
    final source = File('lib/features/giving/pdf/income_form_pdf.dart')
        .readAsStringSync();
    final offenders = source.runes.where((r) => r > 126).toList();
    expect(offenders, isEmpty);
  });

  testWidgets(
      'when the print dialog cannot open, the user is told and the PDF is offered instead',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userRoleProvider.overrideWith(
            (ref) => Stream.value(const UserAccess({UserRole.oversight}))),
        authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: IncomeFormDetailScreen(form: _form())),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Download PDF'), findsOneWidget);
    expect(find.byTooltip('Print'), findsOneWidget);

    // In tests there is no print plugin, so opening the dialog fails -- the
    // same situation as a browser that can't print an embedded PDF.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Print'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(find.textContaining("print dialog didn't open"), findsOneWidget);
  });
}
