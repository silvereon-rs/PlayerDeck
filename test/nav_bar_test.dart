import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playersdeck/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('bottom nav bar shows icon+text for selected page and only icons for unselected pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: AppShell(
          onAccentChanged: (_) {},
          onAccentSaved: (_) {},
          recentColors: const [Color(0xFF7F9D9D)],
          isDarkMode: true,
          onToggleDarkMode: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navBar = find.byType(SafeArea).last;

    // Initial page: Deck (index 0)
    expect(find.descendant(of: navBar, matching: find.text('Deck')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.sports_esports_rounded)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Library')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.text('Settings')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.collections_bookmark_outlined)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.settings_outlined)), findsOneWidget);

    // Tap Library icon -> switches to Library (index 1)
    await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.collections_bookmark_outlined)));
    await tester.pumpAndSettle();

    expect(find.descendant(of: navBar, matching: find.text('Library')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.collections_bookmark_rounded)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Deck')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.text('Settings')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.sports_esports_outlined)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.settings_outlined)), findsOneWidget);

    // Tap Settings icon -> switches to Settings (index 2)
    await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.settings_outlined)));
    await tester.pumpAndSettle();

    expect(find.descendant(of: navBar, matching: find.text('Settings')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.settings_rounded)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Deck')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.text('Library')), findsNothing);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.sports_esports_outlined)), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.byIcon(Icons.collections_bookmark_outlined)), findsOneWidget);
  });
}
