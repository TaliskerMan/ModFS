/// Basic widget tests for the ModFS application.
///
/// These tests verify basic UI rendering, widget interactions, and initial configurations.
library;

import 'package:flutter/material.dart';
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

  testWidgets('Search syntax help opens from the search box', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ModFSApp(prefs: prefs));
    await tester.pump();

    await tester.tap(find.byTooltip('Search syntax'));
    // Let the dialog's open animation finish (pumpAndSettle would wait on the
    // search box's blinking cursor).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Search syntax'), findsWidgets);
    expect(find.text('ext:pdf;docx'), findsOneWidget);
  });

  testWidgets('About shows FSearch first, then the fork, and the GPLv3', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ModFSApp(prefs: prefs));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Original work: FSearch'), findsOneWidget);
    expect(find.text('This fork: ModFS'), findsOneWidget);
    expect(find.textContaining('chuck@nordheim.online'), findsOneWidget);
    expect(find.textContaining('version 3 or (at your option) any later version'), findsOneWidget);
    // The original work is listed before the fork (CP-AboutPage).
    final original = tester.getTopLeft(find.text('Original work: FSearch')).dy;
    final fork = tester.getTopLeft(find.text('This fork: ModFS')).dy;
    expect(original, lessThan(fork));
  });
}
