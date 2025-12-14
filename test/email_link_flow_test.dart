import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/email_link_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Email link send + simulate incoming link (testMode)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MaterialApp(home: EmailLinkAuthPage(testMode: true)));
    await tester.pumpAndSettle();

    // Enter email
    final emailField = find.byType(TextField).first;
    expect(emailField, findsOneWidget);
    await tester.enterText(emailField, 'tester@example.com');
    await tester.pumpAndSettle();

    // Press send
    final sendButton = find.widgetWithText(ElevatedButton, 'Send Sign-in Link (OTP via email link)');
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // Expect stored email badge to appear after sending
    expect(find.textContaining('Test sign-in link sent to'), findsOneWidget);

    // In debug area, find the simulate input and simulate button
    // fallback: pick the second TextField if label matching fails
    final allTextFields = find.byType(TextField);
    expect(allTextFields, findsWidgets);

    // The simulate field is the last TextField in this widget tree
    await tester.enterText(allTextFields.at(1), 'https://example.com/finishSignIn?code=abc');
    await tester.pumpAndSettle();

    final simulateButton = find.widgetWithText(ElevatedButton, 'Simulate incoming link');
    expect(simulateButton, findsOneWidget);
    await tester.tap(simulateButton);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Expect the test sign-in completed message
    expect(find.textContaining('Test sign-in completed for tester@example.com'), findsOneWidget);
  });
}
