import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:church_cms/features/giving/pdf/income_form_pdf.dart';
import 'package:church_cms/features/giving/widgets/signature_pad_field.dart';
import 'package:church_cms/models/giving_record.dart';
import 'package:church_cms/models/sunday_income_form.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

SundayIncomeForm _form({bool signed = true}) => SundayIncomeForm(
      id: 'f',
      date: DateTime(2026, 10, 4),
      service: ServiceType.morning,
      categoryBlocks: {
        for (final c in GivingCategory.values)
          c: const CategoryBlock(denominationBreakdown: {}),
      },
      forexEntries: const [],
      chequeEntries: const [],
      men: 1,
      women: 1,
      children: 1,
      preparedBy: 'Inambao Nanzila',
      checkedBy: 'Msiska Isaac',
      collectedBy: 'Mabai Mike',
      preparedBySignature: signed ? _png : null,
      collectedBySignature: signed ? _png : null,
    );

void main() {
  test('signatures are saved as base64 and left out when absent', () {
    final map = _form().toMap();
    expect(base64Decode(map['preparedBySignature'] as String), _png);
    expect(map.containsKey('checkedBySignature'), isFalse);
    expect(base64Decode(map['collectedBySignature'] as String), _png);

    expect(_form(signed: false).toMap().containsKey('preparedBySignature'), isFalse);
  });

  test('copyWithId keeps the signatures', () {
    final copy = _form().copyWithId('new');
    expect(copy.preparedBySignature, _png);
    expect(copy.checkedBySignature, isNull);
    expect(copy.collectedBySignature, _png);
  });

  test('the PDF renders with and without signatures', () async {
    const values = {'100': 100.0};
    expect((await buildIncomeFormPdf(_form(), values)).isNotEmpty, isTrue);
    expect((await buildIncomeFormPdf(_form(signed: false), values)).isNotEmpty, isTrue);
  });

  testWidgets('drawing on the pad captures a signature and Clear removes it',
      (tester) async {
    final controller = SignaturePadField.newController();
    addTearDown(controller.dispose);
    final drawing = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SignaturePadField(
          label: 'Prepared By signature',
          controller: controller,
          onDrawingChanged: drawing.add,
        ),
      ),
    ));

    expect(controller.isEmpty, isTrue);

    final pad = find.byType(Signature);
    final gesture = await tester
        .startGesture(tester.getCenter(pad) + const Offset(-40, 10));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(10, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(controller.isNotEmpty, isTrue);
    expect(drawing, containsAllInOrder([true, false]));

    final bytes = await tester.runAsync(controller.toPngBytes);
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(controller.isEmpty, isTrue);
  });
}
