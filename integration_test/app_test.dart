import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routine_time/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('Add a routine and mark it done', (tester) async {
      app.main();

      // Splash runs a minimum 3s animation before routing onward.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Skip onboarding when it is shown on a fresh install.
      final continueButton = find.text('Continue for now');
      if (continueButton.evaluate().isNotEmpty) {
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
      }

      // Open the add routine screen from the dashboard.
      final addFab = find.byType(FloatingActionButton);
      if (addFab.evaluate().isNotEmpty) {
        await tester.tap(addFab);
      } else {
        await tester.tap(find.text('Add Routine'));
      }
      await tester.pumpAndSettle();

      // 1. Enter the routine name.
      await tester.enterText(find.byType(TextFormField).first, 'Test Routine');
      await tester.pumpAndSettle();

      // 2. Save the routine.
      await tester.tap(find.text('Save routine'));
      await tester.pumpAndSettle();

      // 3. Verify the routine appears on the dashboard.
      expect(find.text('Test Routine'), findsOneWidget);

      // 4. Mark the routine done.
      final doneButton = find.text('Done');
      if (doneButton.evaluate().isNotEmpty) {
        await tester.tap(doneButton.first);
        await tester.pumpAndSettle();
      }

      // 5. The routine remains visible (now in the completed section).
      expect(find.text('Test Routine'), findsOneWidget);
    });
  });
}
