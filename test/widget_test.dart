
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const PrivacyMedsApp());

    // Verify that the app bar shows MedTime title
    expect(find.text('MedTime - Pill Reminder'), findsOneWidget);
  });
}
