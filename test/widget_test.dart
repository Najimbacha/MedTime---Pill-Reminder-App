
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const PrivacyMedsApp());
    await tester.pump(const Duration(seconds: 4));

    // Verify splash branding is visible on launch
    expect(find.text('MedTime'), findsOneWidget);
  });
}
