import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

// Mock the platform check to avoid Bluetooth initialization
bool mockIsIOS = false;
class MockPlatform {
  static bool get isIOS => mockIsIOS;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset platform mock before each test
    mockIsIOS = false;
  });

  testWidgets('BLE Sports Tracker widget test', (WidgetTester tester) async {
    // Replace Platform.isIOS with our mock
    // ignore: invalid_use_of_visible_for_testing_member
    tester.binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;

    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify that the app title is present
    expect(find.text('BLE Sports Tracker'), findsOneWidget);

    // Verify that the initial data sections are present
    expect(find.text('Real-time Data'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Angle'), findsOneWidget);
    expect(find.text('Power'), findsOneWidget);
    expect(find.text('Direction'), findsOneWidget);

    // Verify initial data values
    expect(find.text('0.00 m/s'), findsOneWidget);
    expect(find.text('0.00°'), findsOneWidget);
    expect(find.text('0.00 W'), findsOneWidget);
    expect(find.text('Unknown'), findsAtLeastNWidgets(1));

    // Verify that the refresh button is present
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
