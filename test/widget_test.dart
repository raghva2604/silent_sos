// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:silent_sos/main.dart';

void main() {
  testWidgets('App boots and shows title', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const AppBootstrap());

    // The splash screen shows the app title 'Silent SOS'. There may be
    // multiple widgets that render the title (header + splash), accept
    // any number of matches but ensure at least one is present.
    expect(find.text('Silent SOS'), findsWidgets);
  });
}
