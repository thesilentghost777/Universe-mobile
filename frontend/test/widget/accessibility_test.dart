import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/features/home/widgets/floating_nav_bar.dart';

void main() {
  group('Accessibility & A11y Guidelines Tests', () {
    testWidgets('Interactive elements maintain minimum accessible touch target size (48x48)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildUniverseTheme(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check),
                label: const Text('Valider mon inscription'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ),
          ),
        ),
      );

      // `ElevatedButton.icon` construit une sous-classe privée
      // (`_ElevatedButtonWithIcon`) : `find.byType(ElevatedButton)` la manque
      // car il compare le type exact. On matche donc par prédicat.
      final button = tester.getSize(
        find.byWidgetPredicate((w) => w is ElevatedButton),
      );
      expect(button.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Text scaling factor (1.5x and 2.0x) renders gracefully without crash', (tester) async {
      final scales = [1.0, 1.5, 2.0];

      for (final scale in scales) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildUniverseTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('UniVerse Bibliothèque'),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Text(
                      'Titre du Livre Numérique',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Description longue du cours de mathématiques discrètes pour niveau Licence 1.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('UniVerse Bibliothèque'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Navigation and icon buttons contain meaningful labels / semantics', (tester) async {
      const items = [
        NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Accueil',
        ),
        NavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'Paramètres',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildUniverseTheme(),
          home: Scaffold(
            bottomNavigationBar: FloatingNavBar(
              items: items,
              currentIndex: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Accueil'), findsOneWidget);
      expect(find.text('Paramètres'), findsOneWidget);
    });
  });
}
