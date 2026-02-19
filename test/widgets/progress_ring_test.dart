/// Widget tests for ProgressRing
/// Tests the circular progress indicator for adherence display

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/widgets/progress_ring.dart';

void main() {
  group('ProgressRing Tests', () {
    Widget createWidgetUnderTest({
      required double progress,
      required int total,
      required int taken,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProgressRing(progress: progress, total: total, taken: taken),
          ),
        ),
      );
    }

    group('Display', () {
      testWidgets('displays percentage text', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.75, total: 4, taken: 3),
        );

        // Wait for animation
        await tester.pumpAndSettle();

        expect(find.text('75%'), findsOneWidget);
      });

      testWidgets('displays taken/total ratio', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.5, total: 10, taken: 5),
        );

        await tester.pumpAndSettle();

        expect(find.text('5 / 10'), findsOneWidget);
      });

      testWidgets('displays COMPLETED label', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 1.0, total: 5, taken: 5),
        );

        await tester.pumpAndSettle();

        expect(find.text('COMPLETED'), findsOneWidget);
      });

      testWidgets('shows 0% for zero progress', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.0, total: 5, taken: 0),
        );

        await tester.pumpAndSettle();

        expect(find.text('0%'), findsOneWidget);
        expect(find.text('0 / 5'), findsOneWidget);
      });

      testWidgets('shows 100% for full progress', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 1.0, total: 3, taken: 3),
        );

        await tester.pumpAndSettle();

        expect(find.text('100%'), findsOneWidget);
        expect(find.text('3 / 3'), findsOneWidget);
      });
    });

    group('Rendering', () {
      testWidgets('has correct size', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.5, total: 10, taken: 5),
        );

        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 220);
        expect(sizedBox.height, 220);
      });

      testWidgets('contains CustomPaint for progress arc', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.5, total: 10, taken: 5),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('uses Stack for layering', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.5, total: 10, taken: 5),
        );

        expect(find.byType(Stack), findsWidgets);
      });
    });

    group('Animation', () {
      testWidgets('animates from 0 to target progress', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 1.0, total: 10, taken: 10),
        );

        // At start, should show 0%
        expect(find.text('0%'), findsOneWidget);

        // After animation
        await tester.pumpAndSettle();
        expect(find.text('100%'), findsOneWidget);
      });

      testWidgets('uses TweenAnimationBuilder', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.5, total: 10, taken: 5),
        );

        expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles progress > 1.0 gracefully', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            progress: 1.5, // Over 100%
            total: 10,
            taken: 15,
          ),
        );

        await tester.pumpAndSettle();

        // Should show calculated percentage
        expect(find.text('150%'), findsOneWidget);
      });

      testWidgets('handles zero total', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: 0.0, total: 0, taken: 0),
        );

        await tester.pumpAndSettle();

        expect(find.text('0 / 0'), findsOneWidget);
      });

      testWidgets('handles negative progress', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(progress: -0.5, total: 10, taken: -5),
        );

        await tester.pumpAndSettle();

        // Widget should still render
        expect(find.byType(ProgressRing), findsOneWidget);
      });
    });

    group('Theme', () {
      testWidgets('renders in light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: Center(
                child: ProgressRing(progress: 0.5, total: 10, taken: 5),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(ProgressRing), findsOneWidget);
      });

      testWidgets('renders in dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: Center(
                child: ProgressRing(progress: 0.5, total: 10, taken: 5),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(ProgressRing), findsOneWidget);
      });
    });
  });
}
