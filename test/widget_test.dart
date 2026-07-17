import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian_child/theme/app_theme.dart';

void main() {
  testWidgets('theme can render a protected status screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('Protection active'))),
      ),
    );

    expect(find.text('Protection active'), findsOneWidget);
  });
}
