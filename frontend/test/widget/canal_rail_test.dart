import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/features/home/widgets/canal_rail.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildUniverseTheme(),
        home: Scaffold(body: Row(children: [child])),
      );

  testWidgets('CanalRail affiche les canaux et le badge de non-lus',
      (t) async {
    String? tapped;
    const canaux = [
      CanalRailItem(id: 'c1', nom: 'Annonces', matiere: 'Algo', nombreNonLus: 3),
      CanalRailItem(id: 'c2', nom: 'TD', matiere: 'Algo'),
    ];

    await t.pumpWidget(host(
      CanalRail(
        loading: false,
        canaux: canaux,
        selectedId: null,
        onSelect: (id) => tapped = id,
        bottomInset: 0,
      ),
    ));
    await t.pump();

    expect(find.text('3'), findsOneWidget);
    // Compact par défaut : une pastille avec l'initiale du canal.
    expect(find.text('A'), findsOneWidget); // Annonces
    expect(find.text('T'), findsOneWidget); // TD

    // Les noms ne sont affichés qu'une fois étendu.
    expect(find.text('Annonces'), findsNothing);
    await t.tap(find.byIcon(Icons.chevron_right_rounded));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.text('Annonces'), findsOneWidget);
    expect(find.text('TD'), findsOneWidget);

    await t.tap(find.text('Annonces'));
    expect(tapped, 'c1');
    expect(t.takeException(), isNull);
  });

  testWidgets('CanalRail se réduit à rien quand il n\'y a aucun canal',
      (t) async {
    await t.pumpWidget(host(
      const CanalRail(
        loading: false,
        canaux: [],
        selectedId: null,
        onSelect: _ignorer,
        bottomInset: 0,
      ),
    ));
    await t.pump();

    expect(find.byType(CanalRail), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(t.takeException(), isNull);
  });
}

void _ignorer(String _) {}
