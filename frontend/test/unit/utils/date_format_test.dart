import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/utils/date_format.dart';

void main() {
  group('Date/heure formatting utilities', () {
    test('memeJour compares calendar days, not exact instants', () {
      final matin = DateTime(2026, 9, 17, 8, 0);
      final soir = DateTime(2026, 9, 17, 23, 59);
      final lendemain = DateTime(2026, 9, 18, 0, 1);

      expect(memeJour(matin, soir), isTrue);
      expect(memeJour(matin, lendemain), isFalse);
    });

    test('heureCourte pads hours and minutes to two digits', () {
      expect(heureCourte(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(heureCourte(DateTime(2026, 1, 1, 23, 45)), '23:45');
    });

    testWidgets(
        'libelleJour returns Aujourd\'hui / Hier / date selon l\'écart',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));

      final maintenant = DateTime.now();
      final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day, 10);
      final hier = aujourdHui.subtract(const Duration(days: 1));
      final ancien = DateTime(2020, 3, 15);

      expect(libelleJour(ctx, aujourdHui), 'Aujourd\'hui');
      expect(libelleJour(ctx, hier), 'Hier');
      expect(libelleJour(ctx, ancien), contains('15 mars'));
      expect(libelleJour(ctx, ancien), contains('2020'));
    });

    testWidgets(
        'heureListe bascule entre heure, jour de semaine et date courte',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));

      final maintenant = DateTime.now();
      final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day, 14, 30);
      final hier = aujourdHui.subtract(const Duration(days: 1));
      final ilYA10Jours = aujourdHui.subtract(const Duration(days: 10));

      expect(heureListe(ctx, aujourdHui), '14:30');
      expect(heureListe(ctx, hier), 'Hier');
      expect(
        heureListe(ctx, ilYA10Jours),
        '${ilYA10Jours.day.toString().padLeft(2, '0')}/'
        '${ilYA10Jours.month.toString().padLeft(2, '0')}',
      );
    });

    testWidgets('ilYA produit un texte relatif court et jamais vide',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));

      final maintenant = DateTime.now();
      expect(ilYA(ctx, maintenant.subtract(const Duration(seconds: 5))), 'à l\'instant');
      expect(ilYA(ctx, maintenant.subtract(const Duration(minutes: 5))), 'il y a 5 min');
      expect(ilYA(ctx, maintenant.subtract(const Duration(hours: 3))), 'il y a 3 h');
      expect(ilYA(ctx, maintenant.subtract(const Duration(days: 2))), 'il y a 2 j');
      expect(ilYA(ctx, maintenant.subtract(const Duration(days: 40))), 'il y a 1 mois');
      expect(ilYA(ctx, maintenant.subtract(const Duration(days: 400))), contains('an'));
    });
  });
}
