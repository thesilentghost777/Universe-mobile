import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/core/auth/role_access.dart';
import 'package:universe_frontend/features/auth/widgets/auth_scaffold.dart';
import 'package:universe_frontend/features/home/widgets/floating_nav_bar.dart';
import 'package:universe_frontend/features/home/widgets/role_home.dart';

void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: buildUniverseTheme(),
          home: child,
        ),
      );

  testWidgets('AuthScaffold renders title, back button and children', (t) async {
    var popped = false;
    await t.pumpWidget(host(
      AuthScaffold(
        title: 'Connexion',
        subtitle: 'Sous-titre',
        onBack: () => popped = true,
        children: const [Text('champ-a'), Text('champ-b')],
      ),
    ));
    await t.pump();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('champ-a'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await t.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(popped, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('RoleHome renders a distinct dashboard for every creator role',
      (t) async {
    final cas = <String, ({RoleAccess acces, String attendu})>{
      'formateur': (
        acces: const RoleAccess(Rang.formateur),
        attendu: 'Publier une vidéo',
      ),
      'enseignant': (
        acces: const RoleAccess(Rang.enseignant, badgeEnseignant: true),
        attendu: 'Publier une vidéo',
      ),
      'tuteur': (
        acces: const RoleAccess(Rang.tuteur),
        attendu: 'Publier une vidéo',
      ),
      'moderateur': (
        acces: const RoleAccess(Rang.moderateur),
        attendu: 'Traiter les signalements',
      ),
    };

    for (final entry in cas.entries) {
      await t.pumpWidget(host(
        Scaffold(body: RoleHome(acces: entry.value.acces)),
      ));
      await t.pump();
      expect(
        find.text(entry.value.attendu),
        findsWidgets,
        reason: 'rôle ${entry.key}',
      );
      expect(t.takeException(), isNull, reason: 'rôle ${entry.key}');
      // Le provider d'auth déclenche un timeout de 2 s au bootstrap : on le
      // laisse s'écouler pour ne pas laisser de Timer en suspens.
      await t.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('FloatingNavBar tient 5 onglets + pastille sur petit écran',
      (t) async {
    t.view.physicalSize = const Size(320, 568); // iPhone SE (1re gén.)
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(host(
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingNavBar(
            currentIndex: 3,
            onSelect: (_) {},
            items: const [
              NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Accueil'),
              NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  label: 'Biblio'),
              NavItem(
                  icon: Icons.play_circle_outline,
                  activeIcon: Icons.play_circle_fill_rounded,
                  label: 'UniTube'),
              NavItem(
                  icon: Icons.forum_outlined,
                  activeIcon: Icons.forum_rounded,
                  label: 'Messages',
                  badge: 12),
              NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Paramètres'),
            ],
          ),
        ),
      ),
    ));
    await t.pump();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget); // pastille plafonnée
    expect(t.takeException(), isNull);
  });

  testWidgets('RoleHome.aUnTableauDeBord distingues le simple étudiant',
      (t) async {
    expect(RoleHome.aUnTableauDeBord(const RoleAccess(Rang.etudiant)), isFalse);
    expect(RoleHome.aUnTableauDeBord(const RoleAccess(Rang.tuteur)), isTrue);
    expect(RoleHome.aUnTableauDeBord(const RoleAccess(Rang.formateur)), isTrue);
  });
}
