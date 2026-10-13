import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/theme/app_theme.dart';
import 'package:church_cms/features/giving/screens/audit_log_screen.dart';
import 'package:church_cms/features/giving/screens/income_forms_list_screen.dart';
import 'package:church_cms/models/audit_entry.dart';
import 'package:church_cms/repositories/repository_providers.dart';

AuditEntry _entry(AuditAction action, String who, String detail) => AuditEntry(
      id: '$action$who',
      action: action,
      entity: 'income_form',
      entityId: 'f1',
      summary: 'Oct 4, 2026 - Morning service',
      detail: detail,
      userId: who,
      userName: who,
      createdAt: DateTime(2026, 10, 9, 14, 5),
    );

Future<void> _pump(WidgetTester tester, Widget home, List<Override> overrides) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('a new entry carries who did what, and nothing is left blank', () {
    final map = AuditEntry.newEntry(
      action: AuditAction.delete,
      entity: 'income_form',
      entityId: 'f1',
      summary: 'Oct 4, 2026 - Morning service',
      detail: 'Total was ZMW 100.00',
      actor: const AuditActor(uid: 'u1', name: 'Daniel Thomas'),
    );
    expect(map['action'], 'delete');
    expect(map['userId'], 'u1');
    expect(map['userName'], 'Daniel Thomas');
    expect(map['entityId'], 'f1');
    expect(map.containsKey('createdAt'), isTrue);
    expect(AuditAction.update.label, 'edited');
  });

  testWidgets('the log lists who created, edited and deleted, newest first',
      (tester) async {
    await _pump(tester, const AuditLogScreen(), [
      auditLogProvider.overrideWith((ref) => Stream.value([
            _entry(AuditAction.delete, 'Ruth', 'Total was ZMW 500.00'),
            _entry(AuditAction.update, 'Daniel', 'Total ZMW 100.00 -> ZMW 200.00'),
            _entry(AuditAction.create, 'Daniel', 'Total ZMW 100.00'),
          ])),
    ]);
    expect(find.text('Ruth deleted a Sunday Income Form'), findsOneWidget);
    expect(find.text('Daniel edited a Sunday Income Form'), findsOneWidget);
    expect(find.text('Daniel created a Sunday Income Form'), findsOneWidget);
    expect(find.textContaining('ZMW 100.00 -> ZMW 200.00'), findsOneWidget);
    expect(find.textContaining('Oct 9, 2026 14:05'), findsWidgets);
  });

  testWidgets('an empty log explains itself', (tester) async {
    await _pump(tester, const AuditLogScreen(),
        [auditLogProvider.overrideWith((ref) => Stream.value([]))]);
    expect(find.textContaining('No activity yet'), findsOneWidget);
  });

  testWidgets('a failed load says so rather than showing an empty log', (tester) async {
    await _pump(tester, const AuditLogScreen(), [
      auditLogProvider.overrideWith((ref) => Stream.error(StateError('denied'))),
    ]);
    expect(find.text('The activity log could not be loaded.'), findsOneWidget);
    expect(find.textContaining('No activity yet'), findsNothing);
  });

  testWidgets('the forms list links to the activity log', (tester) async {
    await _pump(tester, const IncomeFormsListScreen(), [
      incomeFormsProvider.overrideWith((ref) => Stream.value([])),
      auditLogProvider.overrideWith((ref) => Stream.value([])),
    ]);
    await tester.tap(find.byTooltip('Activity log'));
    await tester.pumpAndSettle();
    expect(find.byType(AuditLogScreen), findsOneWidget);
  });
}
