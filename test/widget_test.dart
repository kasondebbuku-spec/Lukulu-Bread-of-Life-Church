import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church_cms/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme renders church branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('Bread of Life Church')),
          ),
        ),
      ),
    );
    expect(find.text('Bread of Life Church'), findsOneWidget);
  });
}
