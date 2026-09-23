import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/core/widgets/universe_glass.dart';
import 'package:universe_frontend/core/widgets/universe_ui.dart';
import 'package:universe_frontend/features/home/widgets/enseignant_nav_bar.dart';
import 'package:universe_frontend/features/home/widgets/floating_nav_bar.dart';
import 'package:universe_frontend/features/settings/settings_widgets.dart';

void main() {
  testWidgets('UniverseIconLabel ne déborde pas dans un segment étroit',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUniverseTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 96,
            child: UniverseIconLabel(
              icon: Icons.dashboard_rounded,
              label: 'Mon espace',
              iconSize: 15,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mon espace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UniversePrimaryButton tient un libellé long à 200 px',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUniverseTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: UniversePrimaryButton(
              label: 'Ajouter une université',
              icon: Icons.add_rounded,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ajouter une université'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FloatingNavBar à 320 px et textScale 1.4 sans overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(
          theme: buildUniverseTheme(),
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: FloatingNavBar(
              currentIndex: 0,
              onSelect: (_) {},
              items: const [
                NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Accueil',
                ),
                NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  label: 'Biblio',
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
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Paramètres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Largeurs réelles : petit téléphone, le format branché (~411), tablette,
  // et un paysage. Échelles : standard, Grande (1,15), Très grande (1,3),
  // et Très grande combinée à une police système déjà grande (1,3 × 1,3).
  const largeurs = [320.0, 360.0, 411.0, 480.0, 844.0];
  const echelles = [1.0, 1.15, 1.3, 1.69];

  const etudiant = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Accueil'),
    NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Biblio'),
    NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
    NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Paramètres'),
  ];

  const tuteur = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Accueil'),
    NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Biblio'),
    NavItem(
      icon: Icons.play_circle_outline,
      activeIcon: Icons.play_circle,
      label: 'UniTube',
      prominent: true,
    ),
    NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
    NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Paramètres'),
  ];

  Future<void> monter(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required Widget child,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildUniverseTheme(),
        builder: (context, contenu) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: contenu!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  for (final largeur in largeurs) {
    for (final echelle in echelles) {
      final nom = '${largeur.toInt()} px × $echelle';

      testWidgets('Barre étudiant $nom', (tester) async {
        await monter(
          tester,
          size: Size(largeur, 800),
          scale: echelle,
          child: FloatingNavBar(
            items: etudiant,
            currentIndex: 3,
            onSelect: (_) {},
          ),
        );
        expect(find.text('Paramètres'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Barre tuteur $nom', (tester) async {
        await monter(
          tester,
          size: Size(largeur, 800),
          scale: echelle,
          child: FloatingNavBar(
            items: tuteur,
            currentIndex: 2,
            onSelect: (_) {},
          ),
        );
        expect(find.text('UniTube'), findsOneWidget);
        expect(find.text('Paramètres'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Barre enseignant $nom', (tester) async {
        await monter(
          tester,
          size: Size(largeur, 800),
          scale: echelle,
          child: EnseignantNavBar(
            items: etudiant,
            currentIndex: 0,
            onSelect: (_) {},
          ),
        );
        expect(find.text('Accueil'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Choix Très grande tient à 260 px et échelle 1,3', (tester) async {
    await monter(
      tester,
      size: const Size(260, 700),
      scale: 1.3,
      child: UniverseSegmentedRow(
        labels: const ['Standard', 'Grande', 'Très grande'],
        selectedIndex: 2,
        onSelect: (_) {},
      ),
    );
    expect(find.text('Très grande'), findsOneWidget);
    expect(find.text('Système'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thème Système tient en clair, police 1,3, largeur 320', (tester) async {
    await monter(
      tester,
      size: const Size(320, 700),
      scale: 1.3,
      theme: buildUniverseLightTheme(),
      child: UniverseSegmentedRow(
        labels: const ['Clair', 'Sombre', 'Système'],
        icons: const [
          Icons.light_mode_outlined,
          Icons.dark_mode_outlined,
          Icons.smartphone_outlined,
        ],
        selectedIndex: 2,
        onSelect: (_) {},
      ),
    );
    expect(find.text('Système'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tuile réglage et bento à 160 px, échelle 1,69', (tester) async {
    await monter(
      tester,
      size: const Size(360, 800),
      scale: 1.69,
      child: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: 160,
                child: SettingsCategoryTile(
                  icon: Icons.person_outline,
                  titre: 'Mon compte',
                  sousTitre: 'Identité, scolarité, sécurité, données',
                  couleur: UniverseColors.blue,
                  onTap: _rien,
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: 160,
                child: BentoTile(
                  icon: Icons.video_call_outlined,
                  titre: 'Publier une vidéo',
                  sousTitre: 'Sous ton accréditation, une fois validée',
                  lockedLabel: 'Après validation',
                ),
              ),
              SizedBox(height: 12),
              SettingsLigne(
                icon: Icons.circle,
                titre: 'Statut en ligne visible',
                sousTitre: 'Les autres voient quand tu es actif.',
                trailing: Switch(value: true, onChanged: null),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Après validation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Barre flottante en thème clair, 411 px, échelle 1,3', (tester) async {
    await monter(
      tester,
      size: const Size(411, 800),
      scale: 1.3,
      theme: buildUniverseLightTheme(),
      child: FloatingNavBar(
        items: tuteur,
        currentIndex: 4,
        onSelect: (_) {},
      ),
    );
    expect(find.text('Paramètres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _rien() {}
