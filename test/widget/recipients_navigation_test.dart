import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_sos/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings opens Recipients picker via route', (WidgetTester tester) async {
    // Provide mock SharedPreferences so SettingsScreen init completes
    SharedPreferences.setMockInitialValues({});

    // Build the app with SettingsScreen and a dummy /recipients route
    await tester.pumpWidget(MaterialApp(
      home: const SettingsScreen(),
      routes: {
        '/recipients': (ctx) => const Scaffold(body: Center(child: Text('RECIPIENTS_DUMMY'))),
      },
    ));

    // Wait for initial frames and async init to complete (bounded pumps)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // There are two 'Open' buttons (Hotword and Recipients). Tap the second one.
    // Tap the Manage Recipients Open button
    final buttonFinder = find.byKey(const Key('manage_recipients_button'));
    expect(buttonFinder, findsOneWidget);
    // Scroll until the button is visible (settings list is scrollable)
    await tester.scrollUntilVisible(buttonFinder, 200.0, scrollable: find.byType(Scrollable));
    await tester.pump();
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify the dummy recipients screen is shown
    expect(find.text('RECIPIENTS_DUMMY'), findsOneWidget);
  });
}
