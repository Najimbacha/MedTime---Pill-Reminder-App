/// Widget tests for EmptyStateWidget
/// Tests the empty state display for various configurations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget Tests', () {
    Widget createWidgetUnderTest({
      required String title,
      required String message,
      IconData? icon,
      String? imageAsset,
      String? buttonText,
      VoidCallback? onButtonPressed,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            title: title,
            message: message,
            icon: icon,
            imageAsset: imageAsset,
            buttonText: buttonText,
            onButtonPressed: onButtonPressed,
          ),
        ),
      );
    }

    group('Display', () {
      testWidgets('displays title and message', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'No Medicines',
            message: 'Add your first medicine to get started',
            icon: Icons.medication,
          ),
        );

        expect(find.text('No Medicines'), findsOneWidget);
        expect(
          find.text('Add your first medicine to get started'),
          findsOneWidget,
        );
      });

      testWidgets('displays icon when provided', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Empty',
            message: 'Nothing here',
            icon: Icons.inbox,
          ),
        );

        expect(find.byIcon(Icons.inbox), findsOneWidget);
      });

      testWidgets(
        'displays button when buttonText and onButtonPressed provided',
        (tester) async {
          var pressed = false;

          await tester.pumpWidget(
            createWidgetUnderTest(
              title: 'Empty',
              message: 'Nothing here',
              icon: Icons.add,
              buttonText: 'Add Item',
              onButtonPressed: () => pressed = true,
            ),
          );

          expect(find.text('Add Item'), findsOneWidget);

          await tester.tap(find.text('Add Item'));
          await tester.pump();

          expect(pressed, isTrue);
        },
      );

      testWidgets('does not display button when buttonText is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Empty',
            message: 'Nothing here',
            icon: Icons.add,
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('does not display button when onButtonPressed is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Empty',
            message: 'Nothing here',
            icon: Icons.add,
            buttonText: 'Add',
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('Theme', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: const EmptyStateWidget(
                title: 'Light Theme',
                message: 'Testing light mode',
                icon: Icons.light_mode,
              ),
            ),
          ),
        );

        expect(find.text('Light Theme'), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: const EmptyStateWidget(
                title: 'Dark Theme',
                message: 'Testing dark mode',
                icon: Icons.dark_mode,
              ),
            ),
          ),
        );

        expect(find.text('Dark Theme'), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('is centered', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Centered',
            message: 'Should be in center',
            icon: Icons.center_focus_strong,
          ),
        );

        expect(find.byType(Center), findsWidgets);
      });

      testWidgets('has proper padding', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Padded',
            message: 'With padding',
            icon: Icons.padding,
          ),
        );

        // Find the outer Padding widget with horizontal: 40
        final paddingFinder = find.ancestor(
          of: find.byType(Column),
          matching: find.byType(Padding),
        );
        expect(paddingFinder, findsWidgets);
      });
    });

    group('Button Interaction', () {
      testWidgets('button has add icon', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'With Button',
            message: 'Has a button',
            icon: Icons.add,
            buttonText: 'Add Medicine',
            onButtonPressed: () {},
          ),
        );

        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      });

      testWidgets('button triggers callback on tap', (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          createWidgetUnderTest(
            title: 'Tappable',
            message: 'Button can be tapped',
            icon: Icons.touch_app,
            buttonText: 'Tap Me',
            onButtonPressed: () => tapCount++,
          ),
        );

        await tester.tap(find.text('Tap Me'));
        await tester.pump();
        expect(tapCount, 1);

        await tester.tap(find.text('Tap Me'));
        await tester.pump();
        expect(tapCount, 2);
      });
    });
  });
}
