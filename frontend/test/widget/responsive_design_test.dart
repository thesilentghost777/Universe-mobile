import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/core/widgets/universe_skeleton.dart';
import 'package:universe_frontend/features/home/widgets/floating_nav_bar.dart';

void main() {
  group('Responsive Design & Screen Dimensions Tests', () {
    final viewports = <String, Size>{
      'Small Mobile (iPhone SE 1st gen)': const Size(320, 568),
      'Standard Mobile (iPhone 14)': const Size(390, 844),
      'Large Android (Pixel 7 Pro)': const Size(412, 915),
      'Tablet Portrait (iPad Mini)': const Size(768, 1024),
      'Mobile Landscape': const Size(844, 390),
    };

    for (final entry in viewports.entries) {
      testWidgets('FloatingNavBar adapts cleanly without overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const items = [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Accueil',
          ),
          NavItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book,
            label: 'Bibliothèque',
          ),
          NavItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: 'Messages',
          ),
          NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Paramètres',
          ),
        ];

        int selectedIndex = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUniverseTheme(),
            home: Scaffold(
              body: const Center(child: Text('Contenu Principal')),
              bottomNavigationBar: FloatingNavBar(
                items: items,
                currentIndex: selectedIndex,
                onSelect: (i) => selectedIndex = i,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(FloatingNavBar), findsOneWidget);
        expect(find.text('Accueil'), findsOneWidget);
        expect(find.text('Messages'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Skeleton loading components scale correctly on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUniverseTheme(),
            home: const Scaffold(
              body: VideoFeedSkeleton(),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(VideoFeedSkeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
