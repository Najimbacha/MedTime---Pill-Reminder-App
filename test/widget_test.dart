import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:routine_time/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const RoutineTimeApp());
    await tester.pump(const Duration(seconds: 4));

    // Verify splash branding is visible on launch
    expect(find.text('RoutineTime'), findsWidgets);
  });
}
