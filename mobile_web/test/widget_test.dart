import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuromood_app/main.dart'; // adjust path if needed

void main() {
  testWidgets('Nuromood app loads and displays widgets', (WidgetTester tester) async {
    // Build the app
   await tester.pumpWidget(const MyApp(firstLaunch: false));


    // Check that TextField is present
    expect(find.byType(TextField), findsOneWidget);

    // Check that Submit button is present
    expect(find.widgetWithText(ElevatedButton, 'Submit'), findsOneWidget);

    // Check that AppBar title is correct
    expect(find.text('Nuromood Journal'), findsOneWidget);
  });
}
