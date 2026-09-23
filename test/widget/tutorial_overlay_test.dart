import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_frontend/features/tutorial/role_tutorial_steps.dart';
import 'package:universe_frontend/features/tutorial/tutorial_overlay.dart';

void main() {
  testWidgets('demarrerTutoriel affiche les etapes puis avance au suivant',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    const etapes = [
      EtapeTutoriel(
        icon: Icons.star_rounded,
        titre: 'Étape un',
        texte: 'Premier texte du tutoriel.',
      ),
      EtapeTutoriel(
        icon: Icons.star_rounded,
        titre: 'Étape deux',
        texte: 'Second texte du tutoriel.',
        pointeur: PointeurDirection.bas,
      ),
    ];

    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => demarrerTutoriel(
            context,
            etapes: etapes,
            userId: 'user-test',
            rang: 'etudiant',
          ),
          child: const Text('lancer'),
        ),
      ),
    ));

    await t.tap(find.text('lancer'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 260));

    expect(find.text('Étape un'), findsOneWidget);
    expect(find.text('Premier texte du tutoriel.'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);

    await t.tap(find.text('Suivant'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('Étape deux'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    // Dernière étape : plus de bouton Passer, "Suivant" devient "Terminer".
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Terminer'), findsOneWidget);

    expect(t.takeException(), isNull);
  });

  testWidgets('demarrerTutoriel ne fait rien si la liste est vide', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => demarrerTutoriel(
            context,
            etapes: const [],
            userId: 'user-test',
            rang: 'etudiant',
          ),
          child: const Text('lancer'),
        ),
      ),
    ));

    await t.tap(find.text('lancer'));
    await t.pump();

    expect(find.text('lancer'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
