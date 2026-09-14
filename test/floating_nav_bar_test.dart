import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/widgets/floating_nav_bar.dart';

void main() {
  group('FloatingNavBar Widget', () {
    testWidgets('renders all items and expands selected item', (tester) async {
      int selectedIndex = 0;
      final keyLog = GlobalKey();
      final keyPantry = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: FloatingNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => setState(() => selectedIndex = index),
                  items: [
                    const FloatingNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    FloatingNavItem(
                      key: keyLog,
                      icon: Icons.add_circle_outline_rounded,
                      selectedIcon: Icons.add_circle_rounded,
                      label: 'Log',
                    ),
                    FloatingNavItem(
                      key: keyPantry,
                      icon: Icons.kitchen_outlined,
                      selectedIcon: Icons.kitchen_rounded,
                      label: 'Pantry',
                      showBadge: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially index 0 ('Home') is selected
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      // Inactive items do not show labels
      expect(find.text('Log'), findsNothing);
      expect(find.text('Pantry'), findsNothing);

      // GlobalKeys are present in tree for tutorial targeting
      expect(find.byKey(keyLog), findsOneWidget);
      expect(find.byKey(keyPantry), findsOneWidget);

      // Badge on Pantry is visible
      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsWidgets);

      // Tap on 'Log'
      await tester.tap(find.byKey(keyLog));
      await tester.pumpAndSettle();

      // Now 'Log' is selected and label is visible
      expect(selectedIndex, 1);
      expect(find.text('Log'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_rounded), findsOneWidget);

      // 'Home' label is hidden
      expect(find.text('Home'), findsNothing);
    });
  });
}
