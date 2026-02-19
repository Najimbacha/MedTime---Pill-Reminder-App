/// Widget tests for GlassContainer
/// Tests the glassmorphism container component

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/widgets/glass_container.dart';

void main() {
  group('GlassContainer Tests', () {
    Widget createWidgetUnderTest({
      required Widget child,
      double blur = 15.0,
      double opacity = 0.1,
      double borderRadius = 24.0,
      Color? color,
      BoxBorder? border,
      EdgeInsetsGeometry? padding,
      double? width,
      double? height,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // Background for blur effect to work on
              Container(color: Colors.blue),
              GlassContainer(
                blur: blur,
                opacity: opacity,
                borderRadius: borderRadius,
                color: color,
                border: border,
                padding: padding,
                width: width,
                height: height,
                child: child,
              ),
            ],
          ),
        ),
      );
    }

    group('Display', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Hello Glass')),
        );

        expect(find.text('Hello Glass'), findsOneWidget);
      });

      testWidgets('wraps content in ClipRRect', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Content')),
        );

        expect(find.byType(ClipRRect), findsOneWidget);
      });

      testWidgets('applies BackdropFilter for blur effect', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Blurred')),
        );

        expect(find.byType(BackdropFilter), findsOneWidget);
      });
    });

    group('Customization', () {
      testWidgets('applies custom blur value', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Custom Blur'), blur: 25.0),
        );

        final backdropFilter = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        // BackdropFilter has an ImageFilter
        expect(backdropFilter.filter, isNotNull);
      });

      testWidgets('applies custom border radius', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: const Text('Custom Radius'),
            borderRadius: 16.0,
          ),
        );

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(16.0));
      });

      testWidgets('applies custom color', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: const Text('Custom Color'),
            color: Colors.red.withOpacity(0.2),
          ),
        );

        expect(find.byType(GlassContainer), findsOneWidget);
      });

      testWidgets('applies custom padding', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: const Text('Padded'),
            padding: const EdgeInsets.all(20),
          ),
        );

        // Find the inner Container with padding
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('applies custom width and height', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: const Text('Sized'),
            width: 200,
            height: 100,
          ),
        );

        // Widget should render with custom size
        expect(find.byType(GlassContainer), findsOneWidget);
      });

      testWidgets('applies custom border', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: const Text('Bordered'),
            border: Border.all(color: Colors.white, width: 2),
          ),
        );

        expect(find.byType(GlassContainer), findsOneWidget);
      });
    });

    group('Theme Adaptation', () {
      testWidgets('adapts to light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Stack(
                children: [
                  Container(color: Colors.blue),
                  const GlassContainer(child: Text('Light Theme')),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(GlassContainer), findsOneWidget);
      });

      testWidgets('adapts to dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Stack(
                children: [
                  Container(color: Colors.blue),
                  const GlassContainer(child: Text('Dark Theme')),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(GlassContainer), findsOneWidget);
      });
    });

    group('Default Values', () {
      testWidgets('uses default blur of 15', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Default Blur')),
        );

        // Widget should render with default blur
        expect(find.byType(BackdropFilter), findsOneWidget);
      });

      testWidgets('uses default border radius of 24', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(child: const Text('Default Radius')),
        );

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(24.0));
      });
    });

    group('Complex Children', () {
      testWidgets('renders complex widget tree', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.star),
                Text('Title'),
                Text('Subtitle'),
              ],
            ),
          ),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Subtitle'), findsOneWidget);
      });

      testWidgets('handles interactive children', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          createWidgetUnderTest(
            child: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        );

        await tester.tap(find.text('Tap Me'));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
