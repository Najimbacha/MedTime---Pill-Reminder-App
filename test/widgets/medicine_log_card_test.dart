/// Widget tests for MedicineLogCard
/// Tests the log card display for different statuses

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_meds/widgets/medicine_log_card.dart';
import 'package:privacy_meds/models/log.dart';

void main() {
  group('MedicineLogCard Tests', () {
    Widget createWidgetUnderTest({
      required String medicineName,
      required String dosage,
      required LogStatus status,
      required DateTime scheduledTime,
      int colorValue = 0xFF2196F3,
      String? iconAssetPath,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MedicineLogCard(
            medicineName: medicineName,
            dosage: dosage,
            status: status,
            scheduledTime: scheduledTime,
            colorValue: colorValue,
          ),
        ),
      );
    }

    group('Display', () {
      testWidgets('displays medicine name', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Aspirin',
            dosage: '100mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 8, 0),
          ),
        );

        expect(find.text('Aspirin'), findsOneWidget);
      });

      testWidgets('displays dosage', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Ibuprofen',
            dosage: '200mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 12, 0),
          ),
        );

        expect(find.text('200mg'), findsOneWidget);
      });

      testWidgets('displays formatted time', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Test Med',
            dosage: '50mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 14, 30), // 2:30 PM
          ),
        );

        expect(find.text('2:30 PM'), findsOneWidget);
      });

      testWidgets('displays AM time correctly', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Morning Med',
            dosage: '25mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 8, 0), // 8:00 AM
          ),
        );

        expect(find.text('8:00 AM'), findsOneWidget);
      });

      testWidgets('displays noon correctly', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Noon Med',
            dosage: '25mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 12, 0), // 12:00 PM
          ),
        );

        expect(find.text('12:00 PM'), findsOneWidget);
      });

      testWidgets('displays midnight correctly', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Midnight Med',
            dosage: '25mg',
            status: LogStatus.take,
            scheduledTime: DateTime(2026, 2, 1, 0, 0), // 12:00 AM
          ),
        );

        expect(find.text('12:00 AM'), findsOneWidget);
      });
    });

    group('Status Display', () {
      testWidgets('shows TAKEN pill for take status', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Taken Med',
            dosage: '100mg',
            status: LogStatus.take,
            scheduledTime: DateTime.now(),
          ),
        );

        expect(find.text('TAKEN'), findsOneWidget);
      });

      testWidgets('shows SKIPPED pill for skip status', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Skipped Med',
            dosage: '100mg',
            status: LogStatus.skip,
            scheduledTime: DateTime.now(),
          ),
        );

        expect(find.text('SKIPPED'), findsOneWidget);
      });

      testWidgets('shows MISSED pill for missed status', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Missed Med',
            dosage: '100mg',
            status: LogStatus.missed,
            scheduledTime: DateTime.now(),
          ),
        );

        expect(find.text('MISSED'), findsOneWidget);
      });

      testWidgets('shows check icon for taken status', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Test',
            dosage: '50mg',
            status: LogStatus.take,
            scheduledTime: DateTime.now(),
          ),
        );

        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      });

      testWidgets('shows error icon for missed status', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Test',
            dosage: '50mg',
            status: LogStatus.missed,
            scheduledTime: DateTime.now(),
          ),
        );

        expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      });
    });

    group('Styling', () {
      testWidgets('has rounded border', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Styled Med',
            dosage: '100mg',
            status: LogStatus.take,
            scheduledTime: DateTime.now(),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, isNotNull);
      });

      testWidgets('applies strikethrough for skipped medication', (
        tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Skipped Med',
            dosage: '100mg',
            status: LogStatus.skip,
            scheduledTime: DateTime.now(),
          ),
        );

        // Find the medicine name text and check its style
        final textWidget = tester.widget<Text>(find.text('Skipped Med'));
        expect(textWidget.style?.decoration, TextDecoration.lineThrough);
      });

      testWidgets('no strikethrough for taken medication', (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Taken Med',
            dosage: '100mg',
            status: LogStatus.take,
            scheduledTime: DateTime.now(),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('Taken Med'));
        expect(textWidget.style?.decoration, isNot(TextDecoration.lineThrough));
      });
    });

    group('Theme', () {
      testWidgets('renders correctly in light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: MedicineLogCard(
                medicineName: 'Light Theme Med',
                dosage: '100mg',
                status: LogStatus.take,
                scheduledTime: DateTime.now(),
                colorValue: 0xFF2196F3,
              ),
            ),
          ),
        );

        expect(find.byType(MedicineLogCard), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MedicineLogCard(
                medicineName: 'Dark Theme Med',
                dosage: '100mg',
                status: LogStatus.take,
                scheduledTime: DateTime.now(),
                colorValue: 0xFF2196F3,
              ),
            ),
          ),
        );

        expect(find.byType(MedicineLogCard), findsOneWidget);
      });
    });

    group('Color', () {
      testWidgets('uses provided color value', (tester) async {
        const customColor = 0xFFFF5722; // Orange color

        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Colored Med',
            dosage: '100mg',
            status: LogStatus.skip, // Use skip so icon uses medicine color
            scheduledTime: DateTime.now(),
            colorValue: customColor,
          ),
        );

        // The widget should render without errors
        expect(find.byType(MedicineLogCard), findsOneWidget);
      });
    });

    group('Computed Properties', () {
      testWidgets('isCompleted is true only for take status', (tester) async {
        // Test taken
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Test',
            dosage: '100mg',
            status: LogStatus.take,
            scheduledTime: DateTime.now(),
          ),
        );
        expect(find.text('TAKEN'), findsOneWidget);

        // Test skipped - should not show TAKEN
        await tester.pumpWidget(
          createWidgetUnderTest(
            medicineName: 'Test',
            dosage: '100mg',
            status: LogStatus.skip,
            scheduledTime: DateTime.now(),
          ),
        );
        expect(find.text('TAKEN'), findsNothing);
        expect(find.text('SKIPPED'), findsOneWidget);
      });
    });
  });
}
