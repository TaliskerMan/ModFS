/// Basic widget tests for the ModFS application.
///
/// These tests verify basic UI rendering, widget interactions, and initial configurations.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:modfs/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main entry point for the ModFS widget test suite.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Smoke test that verifies the app initializes and renders the main title.
  testWidgets('ModFS smoke test', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ModFSApp(prefs: prefs));

    // Verify that the screen title is displayed.
    expect(find.text('ModFS'), findsWidgets);
  });
}
