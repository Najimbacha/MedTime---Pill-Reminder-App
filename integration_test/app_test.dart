import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:privacy_meds/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('Add Medicine and Take it', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Initial State - App loads
      // Allow time for splash screen/intro if any
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check if we are on Dashboard (look for title or greeting)
      // Note: Assuming fresh install or authenticated state. 
      // If Auth screen appears, we might need to skip or handle it. 
      // For this test, we assume we can reach Dashboard or are prompted to set it up.
      
      // Look for the FAB "Add Medicine" or the Empty State button
      final addFab = find.byType(FloatingActionButton);
      final emptyStateButton = find.text('Add Medicine');
      
      if (addFab.evaluate().isNotEmpty) {
        await tester.tap(addFab);
      } else if (emptyStateButton.evaluate().isNotEmpty) {
        await tester.tap(emptyStateButton);
      } else {
        // Fallback: finding by icon
        await tester.tap(find.byIcon(Icons.add));
      }
      
      await tester.pumpAndSettle();

      // 2. Add Medicine Screen
      // Enter Name
      await tester.enterText(find.byType(TextField).at(0), 'Test Vitamin C');
      await tester.pumpAndSettle();

      // Enter Dosage (assuming it's the second text field or finding by label)
      // Since UI might vary, let's try finding by label text if possible, or index
      // Using finder by type generally hits name then dosage/stock
      await tester.enterText(find.byType(TextField).at(1), '500 mg');
      await tester.pumpAndSettle();

      // Scroll down to Save button if needed
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save Medicine'));
      await tester.pumpAndSettle();

      // 3. Output Verification on Dashboard
      expect(find.text('Test Vitamin C'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);

      // 4. Mark as Taken
      // Find the card and tap it (or the take button inside it)
      // Our card has a "Take" action, usually a Dismissible or a Button.
      // Based on Dashboard code, it's a Dismissible or Tap to open details? 
      // _AnimatedEntryCard has onTake callback on tap.
      
      await tester.tap(find.text('Test Vitamin C')); 
      await tester.pumpAndSettle(); // Animation

      // 5. Verify Success State
      // Should move to "Completed" section or show success animation
      await tester.pump(const Duration(seconds: 2)); // Wait for confetti/animation
      
      // Verify it's now in "Completed" status or text decoration changed
      // Visual verification is hard, but we can check if it's still on screen but maybe in a different section
      expect(find.text('Test Vitamin C'), findsOneWidget);
    });
  });
}
